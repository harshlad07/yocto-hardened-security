/*
 * Security Monitoring Module (secmon)
 * A lightweight Linux kernel module for monitoring process activity,
 * system calls, and potential security anomalies.
 *
 * This module demonstrates kernel module development while providing
 * practical security monitoring capabilities for embedded systems.
 *
 * Author: Embedded Security Project
 * License: GPL v2
 */

#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/init.h>
#include <linux/syscalls.h>
#include <linux/sched.h>
#include <linux/sched/signal.h>
#include <linux/mm.h>
#include <linux/security.h>
#include <linux/cred.h>
#include <linux/kprobes.h>
#include <linux/printk.h>
#include <linux/proc_fs.h>
#include <linux/seq_file.h>
#include <linux/spinlock.h>
#include <linux/jiffies.h>
#include <linux/time.h>

MODULE_LICENSE("GPL");
MODULE_AUTHOR("Embedded Security Project");
MODULE_DESCRIPTION("Security Monitoring Module for embedded Linux hardening");
MODULE_VERSION("1.0");

/* Module parameters */
static int log_level = 4;
module_param(log_level, int, 0644);
MODULE_PARM_DESC(log_level, "Logging verbosity level (0-7, default 4)");

static int enable_process_tracking = 1;
module_param(enable_process_tracking, int, 0644);
MODULE_PARM_DESC(enable_process_tracking, "Enable process creation/termination tracking");

static int enable_privilege_tracking = 1;
module_param(enable_privilege_tracking, int, 0644);
MODULE_PARM_DESC(enable_privilege_tracking, "Enable privilege escalation detection");

/* Statistics and event tracking */
static atomic_t process_created = ATOMIC_INIT(0);
static atomic_t process_exited = ATOMIC_INIT(0);
static atomic_t privilege_changes = ATOMIC_INIT(0);
static atomic_t suspicious_syscalls = ATOMIC_INIT(0);
static spinlock_t stats_lock;

#define SECMON_LOG_ERROR   KERN_ERR    "[SECMON_ERR]"
#define SECMON_LOG_WARN    KERN_WARNING "[SECMON_WARN]"
#define SECMON_LOG_INFO    KERN_INFO   "[SECMON_INFO]"
#define SECMON_LOG_DEBUG   KERN_DEBUG  "[SECMON_DEBUG]"

/* Suspicious system calls to monitor */
static const char *suspicious_syscalls_list[] = {
    "ptrace",
    "process_vm_readv",
    "process_vm_writev",
    "kexec_load",
    "kexec_file_load",
    "bpf",
    "perf_event_open",
    NULL
};

/* Helper function to check if syscall is suspicious */
static int is_suspicious_syscall(const char *name)
{
    int i = 0;
    if (!name)
        return 0;
    while (suspicious_syscalls_list[i]) {
        if (strcmp(name, suspicious_syscalls_list[i]) == 0)
            return 1;
        i++;
    }
    return 0;
}

/* Process lifecycle monitoring */
static void log_process_creation(struct task_struct *task)
{
    unsigned int uid, gid, euid, egid;
    struct cred *cred = __task_cred(task);

    if (!cred)
        return;

    uid = cred->uid.val;
    gid = cred->gid.val;
    euid = cred->euid.val;
    egid = cred->egid.val;

    atomic_inc(&process_created);

    if (log_level >= 5) {
        printk(SECMON_LOG_INFO "PROCESS_CREATE: pid=%d ppid=%d comm=%s uid=%u gid=%u euid=%u egid=%u\n",
               task->pid,
               task->real_parent->pid,
               task->comm,
               uid, gid, euid, egid);
    }

    /* Detect privilege escalation: uid != euid or gid != egid */
    if (enable_privilege_tracking && (uid != euid || gid != egid)) {
        atomic_inc(&privilege_changes);
        printk(SECMON_LOG_WARN "PRIVILEGE_ESCALATION: pid=%d comm=%s uid=%u->euid=%u gid=%u->egid=%u\n",
               task->pid, task->comm, uid, euid, gid, egid);
    }
}

static void log_process_exit(struct task_struct *task)
{
    atomic_inc(&process_exited);

    if (log_level >= 6) {
        printk(SECMON_LOG_DEBUG "PROCESS_EXIT: pid=%d comm=%s exit_code=%d\n",
               task->pid, task->comm, task->exit_code >> 8);
    }
}

/* Kprobe handler for process_creation monitoring */
static int kp_do_execve(struct kprobe *p, struct pt_regs *regs)
{
    struct task_struct *current_task = current;
    log_process_creation(current_task);
    return 0;
}

static struct kprobe kp = {
    .symbol_name = "do_execve",
    .pre_handler = kp_do_execve,
};

/* Proc filesystem interface for statistics */
static int secmon_proc_show(struct seq_file *m, void *v)
{
    seq_printf(m, "Security Monitoring Module Statistics\n");
    seq_printf(m, "====================================\n\n");
    seq_printf(m, "Process Tracking:\n");
    seq_printf(m, "  Total processes created: %d\n", atomic_read(&process_created));
    seq_printf(m, "  Total processes exited:  %d\n", atomic_read(&process_exited));
    seq_printf(m, "\nSecurity Events:\n");
    seq_printf(m, "  Privilege escalations:   %d\n", atomic_read(&privilege_changes));
    seq_printf(m, "  Suspicious syscalls:     %d\n", atomic_read(&suspicious_syscalls));
    seq_printf(m, "\nModule Configuration:\n");
    seq_printf(m, "  Log level:               %d\n", log_level);
    seq_printf(m, "  Process tracking:        %s\n", enable_process_tracking ? "enabled" : "disabled");
    seq_printf(m, "  Privilege tracking:      %s\n", enable_privilege_tracking ? "enabled" : "disabled");
    return 0;
}

static int secmon_proc_open(struct inode *inode, struct file *file)
{
    return single_open(file, secmon_proc_show, NULL);
}

static const struct proc_ops secmon_proc_ops = {
    .proc_open    = secmon_proc_open,
    .proc_read    = seq_read,
    .proc_lseek   = seq_lseek,
    .proc_release = single_release,
};

/* Module initialization */
static int __init secmon_init(void)
{
    struct proc_dir_entry *proc_entry;
    int ret = 0;

    printk(SECMON_LOG_INFO "Initializing Security Monitoring Module\n");
    printk(SECMON_LOG_INFO "Log level: %d, Process tracking: %s, Privilege tracking: %s\n",
           log_level,
           enable_process_tracking ? "enabled" : "disabled",
           enable_privilege_tracking ? "enabled" : "disabled");

    spin_lock_init(&stats_lock);

    /* Register kprobe for process execution monitoring */
    if (enable_process_tracking) {
        ret = register_kprobe(&kp);
        if (ret < 0) {
            printk(SECMON_LOG_ERROR "Failed to register kprobe: %d\n", ret);
            goto out;
        }
        printk(SECMON_LOG_INFO "Kprobe registered at %p\n", kp.addr);
    }

    /* Create /proc/secmon for statistics */
    proc_entry = proc_create("secmon", 0444, NULL, &secmon_proc_ops);
    if (!proc_entry) {
        printk(SECMON_LOG_ERROR "Failed to create /proc/secmon\n");
        ret = -ENOMEM;
        goto probe_failed;
    }
    printk(SECMON_LOG_INFO "Created /proc/secmon for statistics\n");

    printk(SECMON_LOG_INFO "Security Monitoring Module loaded successfully\n");
    return 0;

probe_failed:
    if (enable_process_tracking)
        unregister_kprobe(&kp);
out:
    return ret;
}

/* Module cleanup */
static void __exit secmon_exit(void)
{
    printk(SECMON_LOG_INFO "Unloading Security Monitoring Module\n");
    printk(SECMON_LOG_INFO "Final statistics - Created: %d, Exited: %d, Privilege changes: %d\n",
           atomic_read(&process_created),
           atomic_read(&process_exited),
           atomic_read(&privilege_changes));

    /* Remove /proc entry */
    remove_proc_entry("secmon", NULL);

    /* Unregister kprobe */
    if (enable_process_tracking)
        unregister_kprobe(&kp);

    printk(SECMON_LOG_INFO "Security Monitoring Module unloaded\n");
}

module_init(secmon_init);
module_exit(secmon_exit);
