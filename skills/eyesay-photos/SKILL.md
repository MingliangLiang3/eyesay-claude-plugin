---
name: eyesay-photos
description: Tag, sort, search or organise photos with the EyeSay connector. Use when the user wants to know what is in a folder of photos, sort photos into categories or folders, find photos matching a description, or describe a photo.
---

# Photos with EyeSay

Never read the user's photos into the conversation to pass them on. It is slow and costs far more. EyeSay takes them directly, and you read only its summary.

## A folder on the user's computer (you can run commands)

1. Call `prepare_upload`. Replace `<FOLDER>` in the command it returns with the folder path and run the command as it is (Windows: `command_windows` in PowerShell).
2. The command's output is the result: counts, the most frequent tags, failures and links to every photo's tags. Report it. You do not need another call. Running it again sends only what is missing. `job_summary` shows the same result again later.
3. To sort the photos, call `classify_photos` with `images: ["job:<id>"]`. Give the labels in English, translating the user's words. A photo close to none of them goes to `Unsorted`.
4. To search the photos, call `search_photos` with `images: ["job:<id>"]`.
5. To put the photos into folders, run the `organize_command` from `classify_photos` with the same folder. It **copies** each photo into `<folder>/EyeSay/<label>/`. Originals are never moved, renamed or deleted, and deleting `<folder>/EyeSay` undoes it. Add `label=name` pairs so that folder names use the user's own words (e.g. `food=美食`). Move or delete photos only if the user explicitly asks.

Report counts per tag or folder, not lists of file names.

## If a command is blocked

If Claude Code's auto mode blocks the upload or organize command, tell the user and show them the command. The user chooses:
- run it themselves, in their own terminal or after `!` in Claude Code, or
- add allow rules for the EyeSay commands, as described at https://eyesay.app/docs#claude-code-auto-mode.

Never change permission settings yourself.

## No commands (Claude on the web or in the app)

Ask the user to upload the photos at https://eyesay.app/upload, signed in with the same EyeSay account. Then call `list_uploads` and pass `upload:<batch>`, or `upload:<batch>/<n>` for one photo. Each tool takes up to 20 photos per call. Call it again with the rest.

## Reading results

- A tag with `"suggestion": true` is uncertain. Present it as a possibility.
- Every photo counts against the user's EyeSay allowance, and a description or answer counts 3. If a result says a limit was reached, wait a minute before continuing. If it says the allowance is used up, stop and tell the user.
