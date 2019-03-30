### ln-plugin-pony

Lightning Network Plugin written in Pony

### Installation

First, [install](https://github.com/ponylang/ponyc/blob/master/README.md#installation) `pony` itself by using your preferred package manager or compile it from source.

You should also have setup a Lightning Network daemon instance ([c-lightning](https://github.com/ElementsProject/lightning) more precisely)

Start your LN daemon together with the plugin:

```shell
$ /path/to/lightningd --conf=/path/to/conf --plugin=/path/to/ln-plugin-pony
```

### Running

By default the code contains various `debug`outputs that go to **stderr**, because **stdin** and **stdout** must not be used as the daemon uses them to communicate with the plugin. If you don't want to see those diagnose messages simply mute the [_debug](https://github.com/Actinium-project/ln-plugin-pony/blob/master/plugin.pony#L90) function.

### License

[MIT](https://github.com/Actinium-project/ln-plugin-pony/blob/master/LICENSE)
