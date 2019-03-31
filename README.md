### ln-plugin-pony

A [Lightning Network](https://github.com/lightningnetwork/lightning-rfc) Plugin written in [Pony](https://www.ponylang.io/) :horse:

[Support Pony!](https://opencollective.com/ponyc/donate?referral=36826)  ... :+1: Many thanks! :heart:

### Installation

First, [install](https://github.com/ponylang/ponyc/blob/master/README.md#installation) `pony` itself by using your preferred package manager or compile it from source.

You should also have setup a Lightning Network daemon instance ([c-lightning](https://github.com/ElementsProject/lightning) more precisely)

Start your LN daemon together with the plugin:

```shell
$ /path/to/lightningd --conf=/path/to/conf --plugin=/path/to/ln-plugin-pony
```

### Running

By default the code contains various `debug`outputs that go to **stderr**, because **stdin** and **stdout** must not be used as the daemon uses them to communicate with the plugin. If you don't want to see those diagnose messages simply mute Debugger's [print function](https://github.com/Actinium-project/ln-plugin-pony/blob/master/plugin.pony#L26) function.

### Problems

Currently, the plugin only succeeds in exchanging the initial messages with the daemon. Afterwards, it gets closed for no obvious reason. I have followed [this tutorial](https://www.monkeysnatchbanana.com/2016/01/16/pony-patterns-waiting/) to setup a "neverending" Actor but still, the daemon lets the plugin die off. Not sure what the problem is, but as this is my very first project written in Pony I am absolutely sure that *the problem sits in front of my computer*. :sweat_smile:

### License

[MIT](https://github.com/Actinium-project/ln-plugin-pony/blob/master/LICENSE)
