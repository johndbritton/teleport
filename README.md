# Teleport
## A Virtual KVM for macOS

Use one keyboard and pointing device to control multiple Macs.

### Key Features

* __Client__ - Control the keyboard and pointing device of another Mac.
* __Server__ - Allow another Mac to control the system's keyboard and pointing device.
* __Pasteboard Synchronization__ - Copy and paste across Macs.

### Installation

#### Manual

1. Download the [latest release](https://github.com/abyssoft/teleport/releases/latest).
2. Unzip the archive.
3. Drag `Teleport.app` to `/Applications`.

#### Homebrew

```bash
brew install --cask abyssoft-teleport
```

### Project status

Teleport is a legacy project that was once closed source. After the software was discontinued, the original author made the source available to the public and passionate users have been making things work on an ad-hoc basis.

As of [`v1.2.2`](https://github.com/abyssoft/teleport/releases/tag/v1.2.2) All of the key features are known to work on macOS Big Sur.

Teleport previously allowed for file drag and drop between Macs, encrypted network traffic, and status information displays. These features likely work right now, but are unsupported and subject to removal if they break.

Our top priority is to keep the key features working smoothly on the lastest macOS operating system. We are not planning to add any new features, but [contributions are welcome](CONTRIBUTING.md).

#### Current Maintainer

__John Britton__ (@johndbritton)
* [GitHub](https://github.com/johndbritton)
* [Twitter](https://twitter.com/johndbritton)

#### Original Author

__Julien Robert__ (@abyssoft)
* [GitHub](https://github.com/abyssoft)
