## 0.0.5

Bugfixes:

  - fix type of `creator_id` on `File`

## 0.0.4

Features:

  - add `::by_bucket(bucket_name)` scope on `File`
  - add `#file_info`, `#get_uri` on `Command`

## 0.0.3

Features:

  - can pass an optional block while invoking `Command#put`, `Command#mv` and `Command#cp`

## 0.0.2

Bugfixes:

  - fix VFSModule name inflection bug, should use `camelize` instead of `capitalize`
