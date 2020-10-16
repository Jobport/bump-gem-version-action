# bump gem version

A GitHub action to automatically bump the versions of your Ruby Gems after merging a pull request.

### inputs

**`DEFAULT_BUMP_LEVEL`**

`major`/`minor`/`patch`
When given the action will use this default to bump the version if no label is present in the pull request.

**`DRY_RUN`**

`true`/`false`/`""`

do nothing


### outputs

**`skipped`**

`true`/`false`
A boolean that indicates if the gem version was bumped.
Always true when DRY_RUN=true.

**`level`**

`major`/`minor`/`patch`
The bump level that was used.
