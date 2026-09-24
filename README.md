<h1 align="center">OpenXDR KVM Installer</h1>

<p align="center">
  <strong>Automated KVM deployment for Stellar Cyber OpenXDR Data Processor and Sensor components.</strong>
</p>

<p align="center">
  Detect hardware, prepare KVM/libvirt, configure networking and storage, then deploy through guided TUI workflows.
</p>

<p align="center">
  <strong>English</strong> · <a href="README.ko.md">한국어</a> · <a href="https://kvm.xdr.ooo/">Documentation</a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/platform-KVM-2563EB?style=flat-square" alt="KVM">
  <img src="https://img.shields.io/badge/runtime-libvirt-7C3AED?style=flat-square" alt="libvirt">
  <img src="https://img.shields.io/badge/host-Ubuntu-E95420?style=flat-square&logo=ubuntu&logoColor=white" alt="Ubuntu">
  <img src="https://img.shields.io/badge/UI-whiptail%20TUI-16A34A?style=flat-square" alt="whiptail TUI">
</p>

---

## What it does

OpenXDR KVM Installer automates the host-side work required to deploy Stellar Cyber OpenXDR components on KVM.

It provides guided workflows for:

- hardware/NIC/disk discovery
- KVM and libvirt setup
- networking and bridge/NAT configuration
- SR-IOV and PCI passthrough where required
- LVM-backed VM storage
- image and VM deployment
- CPU affinity and performance tuning
- step state, reboot, and resume
- DRY_RUN and configuration validation

## Installer families

| Installer | Purpose |
|---|---|
| `DP-Installer.sh` | Data Processor deployment |
| `Sensor-Installer.sh` | Standard Modular Sensor deployment |
| `6000-Sensor-Installer.sh` | High-performance dual-VM Sensor deployment |
| `AIO-Sensor-Installer.sh` | AIO Data Processor + Sensor deployment |

Choose the installer that matches the target topology. Installer-specific sizing, supported OS/version details, networking, and step sequences are maintained in the documentation site.

## Quick start

Switch to a root login shell **before** cloning so the working directory remains predictable:

```bash
sudo -i

git clone https://github.com/xdr-labs/OpenXDR-KVM-Installer.git
cd OpenXDR-KVM-Installer
```

Run the required installer:

```bash
# Data Processor
./DP-Installer.sh

# Standard Sensor
./Sensor-Installer.sh

# High-performance Sensor
./6000-Sensor-Installer.sh

# AIO + Sensor
./AIO-Sensor-Installer.sh
```

Keep **DRY_RUN enabled** while reviewing hardware, networking, storage, versions, credentials, and calculated VM resources.

Run **Full Configuration Validation** before real execution. Resolve every FAIL and review WARN results.

Only then set:

```text
DRY_RUN=0
```

and execute the required steps.

## Reboot and resume

Some network/kernel steps intentionally require a reboot.

After reboot:

1. return to the same installer directory
2. run the same installer again
3. continue from the saved state

Do not manually manipulate the installer state simply to skip a failed or incomplete step.

## Safety

With real execution enabled, the installers can modify:

- network interfaces and naming
- routing/bridge configuration
- kernel settings
- KVM/libvirt configuration
- LVM/storage layout
- VM definitions
- PCI/SR-IOV assignment

When working remotely, secure console or out-of-band access before applying network/storage changes.

## Common requirements

Exact requirements depend on the selected installer, but the common baseline includes:

- a supported Ubuntu Server release for that installer
- root privileges
- Intel VT-x or AMD-V
- Intel VT-d or AMD-Vi when using PCI passthrough/SR-IOV
- sufficient CPU, memory, and local storage for the target VMs
- management connectivity
- SPAN/data NICs where required
- access to required Stellar component images/packages

Do not treat a generic README minimum as production sizing. Use the installer-specific documentation and Stellar sizing for the actual deployment.

## Post-deployment operations

The installers can install **Stellar Appliance CLI** for day-2 operations.

Stellar Appliance CLI handles supported network, NTPsec, ACL, VM, and system operations after deployment. It is not a replacement for the deployment installers.

See:

- https://kvm.xdr.ooo/operations/appliance-cli
- https://github.com/xdr-labs/Stellar-appliance-cli

## Documentation

Use **https://kvm.xdr.ooo/** as the maintained user and operator guide.

Start with:

- Choose an Installer
- Deployment Method
- Requirements
- Ubuntu 24.04 preparation
- Quickstart
- installer-specific guides
- troubleshooting

The documentation site is intentionally the detailed reference so this README does not duplicate hundreds of lines of operational instructions.

## Related projects

- XDR Labs Portal: https://xdr.ooo/
- Stellar Appliance CLI: https://github.com/xdr-labs/Stellar-appliance-cli

---

<p align="center">
  <strong>Detect. Validate. Deploy. Resume safely after reboot.</strong>
</p>
