# Kies
Universal fuzzy selector for macOs comparable with dmenu

- Gets list of items from stdin.
- Fuzzy-searches as you type.
- Sends result to stdout.
- Run choose -h for more info.

## Install

1. Download the latest release (or build it) and place it in `/Applications`.
2. Make an alias in your shell
    - Bash: `alias kies="/Applications/kies.app/Contents/MacOS/kies"`


## Usage

```bash
$ ls | kies
```

### Examples
- [Example vim integration](examples/kies.vim)
![vim example screenshot](screenshots/vim.png)
- [Example application launcher](examples/run.sh)
![run example screenshot](screenshots/run.png)

## License

> Released under MIT license.
>
> Copyright (c) 2018 Thomas Billiet
>
> Permission is hereby granted, free of charge, to any person obtaining a copy
> of this software and associated documentation files (the "Software"), to deal
> in the Software without restriction, including without limitation the rights
> to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
> copies of the Software, and to permit persons to whom the Software is
> furnished to do so, subject to the following conditions:
>
> The above copyright notice and this permission notice shall be included in
> all copies or substantial portions of the Software.
>
> THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
> IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
> FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
> AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
> LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
> OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
> THE SOFTWARE. 
