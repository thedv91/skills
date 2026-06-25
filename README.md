# thedv91-skills

A Claude Code [plugin marketplace](https://code.claude.com/docs/en/plugin-marketplaces) of skills for code review and React best practices.

## Plugins

| Plugin | Description |
| --- | --- |
| `review-code-change` | Review the diff of the current branch against a target branch against extensible standards (security, performance, business logic, React/Next.js/Node/TypeScript). Read-only git. Invoke with `/review-code-change:review-code-change`. |
| `react-compiler` | Write React components and hooks fully compatible with React Compiler's automatic memoization. |
| `react-effect-event` | Use React's `useEffectEvent` to separate reactive dependencies from non-reactive latest-value reads inside Effects. React 19.2+. |

## Install

Add the marketplace, then install the plugins you want:

```shell
/plugin marketplace add thedv91/skills
/plugin install review-code-change@thedv91-skills
/plugin install react-compiler@thedv91-skills
/plugin install react-effect-event@thedv91-skills
```

Or from the CLI:

```shell
claude plugin marketplace add thedv91/skills
claude plugin install review-code-change@thedv91-skills
```

Update later with `/plugin marketplace update thedv91-skills`.

## Layout

```
.claude-plugin/marketplace.json   # marketplace catalog
plugins/<name>/
  .claude-plugin/plugin.json      # plugin manifest
  skills/<name>/SKILL.md          # the skill
```

## Validate

```shell
claude plugin validate .                       # marketplace.json
claude plugin validate ./plugins/review-code-change   # a plugin manifest + skill frontmatter
```
