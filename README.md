# EyeSay plugin for Claude

EyeSay tags, sorts and searches photos for Claude. This plugin pairs the EyeSay connector (`https://eyesay.app/mcp`) with one skill, `eyesay-photos`. The skill tells Claude how to hand EyeSay a whole folder of photos without reading the photos into the conversation, which is slow and expensive. Claude then reads only EyeSay's summary.

## Install

In Claude Code, add this repository as a plugin marketplace, then install the plugin from it:

```text
/plugin marketplace add MingliangLiang3/eyesay-claude-plugin
/plugin install eyesay@eyesay
```

`/plugin install` opens the plugin's details, where you choose a scope and install. From your shell, the same two steps are `claude plugin marketplace add MingliangLiang3/eyesay-claude-plugin` and `claude plugin install eyesay@eyesay`.

## Account and sign-in

The plugin needs an EyeSay account. A free account includes 1,000 photos a month. The first time Claude uses the connector, you sign in to EyeSay with OAuth in your browser: in Claude Code, run `/mcp`, select the EyeSay server and sign in; in Claude on the web, in the app or in Cowork, connect **EyeSay** on the plugin's Connectors tab.

## Use it

- In Claude Code or Cowork, ask for example: "Use EyeSay to tag the photos in ~/Pictures/trip", then "sort them into food, people and documents" and "put them into folders".
- In Claude on the web or in the app, upload photos at https://eyesay.app/upload, signed in with the same account, then ask Claude to tag, sort or describe them.

## What it runs, sends and changes

- The plugin contains this README, the license, two manifests, the connector's address, the skill's instructions and two small scripts in `skills/eyesay-photos/scripts/` (shell for macOS and Linux, PowerShell for Windows). It has no hooks and downloads no code.
- Through the connector, Claude calls EyeSay's tools. In Claude Code or Cowork, Claude runs the bundled `intake.sh` (or `intake.ps1` on Windows) with a job link and token from EyeSay; it sends each photo in the folder you name to eyesay.app and prints the result. Claude Code may ask you to confirm before it runs.
- To sort photos into folders, Claude runs the bundled `organize.sh` (or `organize.ps1`), which **copies** them into an `EyeSay` folder inside the folder you named. Your originals are never moved, renamed or deleted; deleting that `EyeSay` folder undoes it.

## Privacy

Photos go only to eyesay.app. They are processed in memory and not kept. A folder job keeps only each photo's results (its tags and search vectors, with its file name and folder path and a fingerprint of the file), never the photo itself, for 24 hours. Photos uploaded at https://eyesay.app/upload are held in memory for at most 30 minutes. Details: https://eyesay.app/privacy.

## Support

support@eyesay.app · Docs: https://eyesay.app/docs · Terms: https://eyesay.app/terms
