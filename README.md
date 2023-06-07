# Maple Open-Term Loan Manager

[![Foundry CI](https://github.com/maple-labs/open-term-loan-manager/actions/workflows/forge.yaml/badge.svg)](https://github.com/maple-labs/open-term-loan-manager/actions/workflows/forge.yaml)
[![GitBook - Documentation](https://img.shields.io/badge/GitBook-Documentation-orange?logo=gitbook&logoColor=white)](https://maplefinance.gitbook.io/maple/technical-resources/protocol-overview)
[![Foundry](https://img.shields.io/badge/Built%20with-Foundry-FFDB1C.svg)](https://getfoundry.sh/)
[![License: BUSL 1.1](https://img.shields.io/badge/License-BUSL%201.1-blue.svg)](https://github.com/maple-labs/open-term-loan-manager/blob/main/LICENSE)

## Overview

This repository contains the contracts that are responsible for the deployment and management of Maple Open-Term Loan Managers:

## Dependencies/Inheritance

Contracts in this repo inherit and import code from:
- [`maple-labs/erc20-helper`](https://github.com/maple-labs/erc20-helper)
- [`maple-labs/maple-proxy-factory`](https://github.com/maple-labs/maple-proxy-factory)

Contracts inherit and import code in the following ways:
- `LoanManager` inherits `MapleProxiedInternals` for proxy logic.
- `LoanManagerFactory` inherits `MapleProxyFactory` for proxy deployment and management.

Versions of dependencies can be checked with `git submodule status`.

## Setup

This project was built using [Foundry](https://book.getfoundry.sh/). Refer to installation instructions [here](https://github.com/foundry-rs/foundry#installation).

```sh
git clone git@github.com:maple-labs/open-term-loan-manager.git
cd open-term-loan-manager
forge install
```

## Running Tests

- To run all tests: `forge test`
- To run specific tests: `forge test --match <test_name>`

`./scripts/test.sh` is used to enable Foundry profile usage with the `-p` flag. Profiles are used to specify the number of fuzz runs.

## Audit Reports

### June 2023 Release

| Auditor | Report Link |
|---|---|
| Spearbit Auditors via Cantina | [`2023-06-05 - Cantina Report`](https://docs.google.com/viewer?url=https://github.com/maple-labs/maple-v2-audits/files/11667848/cantina-maple.pdf) |
| Three Sigma | [`2023-04-10 - Three Sigma Report`](https://docs.google.com/viewer?url=https://github.com/maple-labs/maple-v2-audits/files/11663546/maple-v2-audit_three-sigma_2023.pdf) |

## Bug Bounty

For all information related to the ongoing bug bounty for these contracts run by [Immunefi](https://immunefi.com/), please visit this [site](https://immunefi.com/bounty/maple/).

## About Maple

[Maple Finance](https://maple.finance/) is a decentralized corporate credit market. Maple provides capital to institutional borrowers through globally accessible fixed-income yield opportunities.

---

<p align="center">
  <img src="https://user-images.githubusercontent.com/44272939/196706799-fe96d294-f700-41e7-a65f-2d754d0a6eac.gif" height="100" />
</p>
