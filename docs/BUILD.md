# Build the operator manual

Generate a static HTML edition from the Markdown pages in `docs/`.

## Prerequisites

- mdBook 0.5.4 available as `mdbook` on `PATH`.
- A repository checkout containing `book.toml` and `docs/`.

## Generate the HTML manual

1. From the repository root, build the manual:

   ```bash
   mdbook build
   ```

   mdBook reads `docs/SUMMARY.md` and writes the rendered pages and search assets to `book/`. Missing chapter files cause the build to fail.

## Verification

Require exit status zero from the build. Confirm that the entry page exists:

```bash
test -s book/index.html
```

Open `book/index.html` in a browser. Use the chapter navigation to read the manual. Generated files remain outside version control.
