# Architecture overview

This document describes the architecture of the `yocto-hardened-security` project, which is designed to demonstrate a hardened embedded Linux distribution built using Yocto and security-focused kernel instrumentation.

## 1. Objectives

The main goals are:
- build a custom Yocto image for a security-oriented embedded Linux system
- apply Linux kernel hardening best practices
- include security audit and monitoring components
- implement a device-driver-style kernel module for security monitoring
- validate the full setup using QEMU without physical hardware

## 2. System overview

The system is composed of several layers:

1. Yocto build system
   - creates the Linux distribution
   - manages layers, recipes, and image generation

2. Hardened Linux kernel
   - configured with defensive options
   - stripped down to reduce the attack surface
   - includes relevant security features

3. Security monitoring module (`secmon`)
   - implemented as a Linux loadable kernel module (LKM)
   - collects security-relevant events from kernel space
   - provides a driver-like proof of kernel development capability

4. User-space security stack
   - auditd for logging and rule-based audit events
   - rsyslog for log handling
   - optional file integrity tools for monitoring changes

5. Emulator runtime
   - QEMU boots the image for testing and demonstration
   - no hardware flashing required

## 3. Layered architecture

```text
User space
  ├── auditd
  ├── rsyslog
  ├── apparmor or similar policy enforcement
  └── security scripts / collectors

Kernel space
  ├── hardened Linux kernel
  ├── security monitoring LKM (secmon)
  ├── audit subsystem
  └── syscall / process metadata hooks

Yocto build layer
  ├── meta-security
  ├── recipes-core images
  ├── recipes-kernel customizations
  └── recipes-security packages

QEMU environment
  └── emulated target board / VM
```

## 4. Yocto layer design

The `meta-security` layer will contain:
- kernel configuration customizations
- security-related packages
- image recipe for a hardened embedded image
- module recipe for the `secmon` kernel module

This layer allows the security policy to stay modular and isolated from the base distribution.

## 5. Kernel hardening strategy

The hardened kernel will focus on common defensive principles such as:
- disabling unnecessary kernel features
- enabling stack protection and memory protections
- reducing dynamic module exposure where appropriate
- enabling audit and tracing features
- limiting attack surface in the image configuration

The exact configuration may evolve based on the target architecture and Yocto version used.

## 6. Security monitoring module (`secmon`)

The `secmon` LKM is the bridge between kernel internals and the security model of the project. It is intended to:
- monitor process lifecycle events
- track interesting system calls
- log suspicious operations to user space
- provide a basic detection signal for potentially malicious behavior

This logical component also satisfies the requirement to show some device-driver-related capability without requiring actual hardware.

## 7. Device-driver relevance

Although this is not a hardware-specific controller driver, the module still demonstrates:
- Linux kernel module development
- kernel API familiarity
- low-level monitoring of system operations
- module loading and interaction patterns

This is relevant for embedded and driver-focused profiles while remaining practical in an emulated environment.

## 8. Cybersecurity perspective

This project is meant to show practical cyber security understanding through:
- defense-in-depth
- audit logging and visibility
- anomaly detection concepts
- reduced privilege and secure configuration
- embedded environment hardening

It aims to present a realistic embedded security posture rather than a purely theoretical description.

## 9. QEMU validation workflow

The project will validate behavior through QEMU by:
1. building the customized image with Yocto
2. booting it in QEMU
3. loading the `secmon` module
4. observing system activity and logs
5. testing suspicious conditions to confirm security monitoring behavior

This makes the project suitable for a portfolio without needing a hardware board.

## 10. Expected outcome

The final result is a portfolio-friendly project that shows:
- understanding of Yocto
- practical Linux hardening techniques
- cybersecurity-oriented system design
- kernel/module development experience
- ability to test embedded security on emulated hardware

## 11. Future improvements

Potential extensions include:
- file integrity monitoring
- stricter rule-based detection
- integration with automated security checks
- secure boot concepts in future versions
- stronger module-based threat modeling

## Summary

This project is intentionally designed to balance embedded Linux engineering with cyber security and driver knowledge. It is practical, relevant, and can be fully demonstrated on QEMU without flashable hardware.
