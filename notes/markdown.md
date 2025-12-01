# Markdown

## Previewing Markdown

```sh
redcarpet --parse fenced_code_blocks my-file.md > my-file.html
# Continuously:
echo "my-file.md" | entr -c -s "redcarpet --parse fenced_code_blocks my-file.md > my-file.html"
```

## Spoiler text

```markdown
<details>
<summary>Spoiler warning</summary>

Spoiler text. Note that it's important to have a space after the summary tag.

```sh
echo "code block"
```

</details>
```

## Tools

- [markdownlint](https://github.com/DavidAnson/markdownlint)
- [mdlynx](https://github.com/langston-barrett/mdlynx)
- redcarpet
- [typos](https://github.com/crate-ci/typos)
