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
This allows the fields to be set from the commandline, from
`mpv.conf`, and from profiles, including
[conditional auto profiles](https://mpv.io/manual/master/#conditional-auto-profiles).

The script-opt is in the form `user-data/path/to/field=<JSON value><parameters>`.
It is nearly identical to the `user-data.conf` syntax, except that
the keys must be prefixed with `user-data/` and a list of parameters can optionally
be appended to the end (see [script-opt parameters](#script-opt-parameters)).

If a `script-opt` is removed, then the associated `user-data` field is
reset to the value it had when the first script-opt was applied.
This behaviour can be changed with the [`restore` parameter](#restore).

If, by some unfortunate coincidence, you are using a script that uses the
`user-` prefix (or perhaps you just prefer underscores)
you can substitute the `-` for a `_`, e.g. `user_data/path/to/field=<JSON value>`.

### script-opt parameters
Parameters are a list of optional key-value pairs appended after the
JSON value in the form `<key>=<value>`. Whitespace around the `=` is allowed and
parameters can be separated from the JSON value (and each other) using any
character **except** the following: `a-zA-Z0-9_-`.

Here are some examples with valid syntax:

```properties
script-opts-append=user-data/script_name/visibility=true|param=val|param2=val
script-opts-append=user-data/script2/num=21: param = val param2=val
script-opts-append=user-data/script2/text/header="header text" param = val
```

Currently there is only one parameter, `restore`, which
behaves similarly to the mpv
[`profile-restore`](https://mpv.io/manual/master/#runtime-profiles)
option.

#### `restore`
This parameter controls what happens when the script-opt is removed.
There are three options:

option       | description
-------------|-------------------------------------------------------------------------------------------------------
`copy`       | Copy the original value of the field and restore it when the script-opt is removed (default).
`copy-equal` | Copy the original value, but only restore if the current field value is equal to the value set by the script-opt.
`no`         | Do not do anything when the script-opt is removed.

Currently, if a script-opt is changed instead of removed,
then only the `restore` value of the original script-opt is
considered (unless that original value was `no`).
This may change in the future.


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
Sets a `primary-monitor` field based on the
monitor the mpv window is currently displayed on.
The default value would be better placed in `user-data.conf`
where the `restore=no` would not be necessary. It has been
placed here to make the example easier to read.

```properties
# sets the default value (probably better to do this is a config file)
script-opts-append=user-data/primary-monitor=false|restore=no

[PrimaryMonitor]
profile-cond=display_names[1] == 'DP-1'
script-opts-append=user-data/primary-monitor=true|restore=copy-equal

[OtherMonitor]
profile-cond=display_names[1] ~= 'DP-1'
script-opts-remove=user-data/primary-monitor
```

Uses user-data property expansion to append `PRIMARY MONITOR` to the
title of the mpv window:

```properties
title='${?media-title:${media-title}}${!media-title:No file} - mpv${?user-data/primary-monitor: - PRIMARY MONITOR}'

[PrimaryMonitor]
profile-cond=display_names[1] == 'DP-1'
script-opts-append=user-data/primary-monitor=true|restore=copy-equal

[OtherMonitor]
profile-cond=display_names[1] ~= 'DP-1'
script-opts-remove=user-data/primary-monitor
```

#### Commandline

```bash
mpv --script-opts-append='user-data/script_name/visibility=true' \
    --script-opts-append='user-data/script2/number-of-items=21' \
    --script-opts-append='user-data/script2/text/header="header text"'
```

Make sure that the `"` characters around strings are not stripped by the shell.
