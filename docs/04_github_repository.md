# GitHub repository

## What was done
We put the project in a git repository with the name `dispace`. We wrote a README for GitHub readers. It tells what Dispace does, the requirements, the build steps, daily use, the private APIs, and the known limits. The `.gitignore` file keeps the build output out of the repository. We also corrected the Raycast note in `docs/03_build_and_install.md`, because the user confirmed that Raycast finds Dispace.

## Files created / modified
| File | Action | Purpose |
|------|--------|---------|
| `README.md` | Created | Project page on GitHub: purpose, requirements, build, use, limits |
| `.gitignore` | Created | Keeps `build/` and `.DS_Store` out of the repository |
| `docs/03_build_and_install.md` | Modified | Records that Raycast finds Dispace |
| `docs/04_github_repository.md` | Created | This file |

## Why it matters
The repository has all the files that a build needs: the sources, `Info.plist`, the icon script, and `build.sh`. A new clone builds with `./build.sh` and gives the same app. The `build/` folder is not in the repository, because `build.sh` creates it again.

The README states the limits clearly. Dispace depends on private macOS functions, and a macOS update can remove them. A reader must know this before they install the app.
