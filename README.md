# mpv-user-data-loader
A script that allows the mpv `user-data` property to be more easily
configured using config files.

The script does this in two ways:
* `user-data` fields can be set on startup using config files.
* `user-data` fields can be set during runtime using `script-opts`.

## Changing Properties at Startup
There are a few different ways of setting
`user-data` fields at startup.

### Config File
`~~/script-opts/user-data.conf`

This is a config file that uses the standard
[script config syntax](https://mpv.io/manual/master/#lua-scripting-on-update]]%29)
of `<key>=<value>`.

`key` is the path to the `user-data` field that will be modified, e.g.
`script_name/visibility`.
`value` is the JSON formatted value that will be set to that field.
The `/` and `=` characters are not supported in any of the field names for this
config file, even though the `user-data` property does support those characters.

Example:

```properties
# comment
script_name/visibility=true
script2/number-of-items=21
script2/text/header="header text"
```

`user-data` output:
```json
{
    "script_name": {
        "visibility":true
    },
    "script2": {
        "number-of-items": 21,
        "text": {
            "header": "header text"
        }
    }
}
```

### JSON Config File
`~~/script-opts/user-data.json`

This config file uses JSON syntax, which should make it
easier to define highly nested `user-data` values.

The file represents the full `user-data` property,
so to replicate the previous example
the json file could simply contain:

```json
{
    "script_name": { "visibility":true },
    "script2": {
        "number-of-items": 21,
        "text": { "header": "header text" }
    }
}
```

Note that all of the top-level fields (e.g. `script_name` and `script2`)
directly overwrite the existing value in `user-data`.
This means that if `script_name/other_field` exists in `user-data`,
it will be removed after `"script_name": { "visibility":true }` is applied.
This will likely change in the future.

The JSON file can be used in conjunction with `user-data.conf`.
The JSON file will be applied first, so will not overwrite
the values set in `user-data.conf`.

### `script-opts`
The [`script-opts`](https://mpv.io/manual/master/#options-script-opts)
property can also be set at startup using `mpv.conf` or with
commandline arguments. See
[changing properties at runtime](#changing-properties-at-runtime) for
the correct syntax.

Values set with script-opts always overwrite the config files.

## Changing Properties at Runtime
`user-data` fields can be modified at runtime using
[`script-opts`](https://mpv.io/manual/master/#options-script-opts).
This allows thew fields to be set from the commandline, from
`mpv.conf`, and from profiles, including
[conditional auto profiles](https://mpv.io/manual/master/#conditional-auto-profiles).

The script-opt is in the form `user-data/path/to/field=<JSON value>`.
It is nearly identical to the `user-data.conf` syntax, except that
the keys must be prefixed with `user-data/`.

If a `script-opt` is removed, then the associated `user-data` field is
reset to the value it had when the first script-opt was applied.
This nearly equivalent to the behaviour of
[`profile-restore=copy`](https://mpv.io/manual/master/#runtime-profiles).
An option to use `profile-restore=copy-equal` behaviour may be added
in the future.

### Examples

#### `mpv.conf`

```properties
script-opts-append=user-data/script_name/visibility=true
script-opts-append=user-data/script2/number-of-items=21
script-opts-append=user-data/script2/text/header="header text"
```

Applying the script-opts with a profile:
```properties
[profile1]
script-opts-append=user-data/script_name/visibility=true
script-opts-append=user-data/script2/number-of-items=21
script-opts-append=user-data/script2/text/header="header text"
```

#### Conditional Auto Profiles
Sets a `monitor-name` field depending on
which monitor the mpv window is currently displayed on.

```properties
[DELL]
profile-cond=display_names[1] == 'DP-1'
profile-restore=copy
script-opts-append=user-data/monitor-name="DELL Monitor"

[OtherBrand]
profile-cond=display_names[1] ~= 'DP-1'
profile-restore=copy
script-opts-append=user-data/monitor-name="Other Monitor"
```

#### Commandline

```bash
mpv --script-opts-append='user-data/script_name/visibility=true' \
    --script-opts-append='user-data/script2/number-of-items=21' \
    --script-opts-append='user-data/script2/text/header="header text"'
```

Make sure that the `"` characters around strings are not stripped by the shell.
