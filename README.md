# Codex Reset LINE Notifier

This repository runs a GitHub Actions workflow every 5 minutes to check:

- `https://www.hascodexratelimitreset.today/api/status`

It sends one LINE message only when the site changes from `no` to `yes`.

## What you need

1. A GitHub repository for these files
2. A LINE Official Account with Messaging API enabled
3. A `LINE_CHANNEL_ACCESS_TOKEN` GitHub secret

## GitHub setup

1. Create a new GitHub repository.
2. Upload everything in this folder to that repository.
3. In GitHub, open `Settings -> Secrets and variables -> Actions`.
4. Create a new repository secret named `LINE_CHANNEL_ACCESS_TOKEN`.
5. Paste your LINE Messaging API channel access token as the secret value.
6. Open the `Actions` tab and enable workflows if GitHub asks.

## First test

1. Open the `Actions` tab.
2. Open the workflow `Check Codex Reset`.
3. Click `Run workflow`.
4. Turn on `force_notify`.
5. Run it once.

That manual run sends a LINE test message immediately.

## How state is stored

The workflow writes its last seen state to:

- `.github/state/codex-reset-state.json`

That file is committed back to the repository automatically so the next run knows whether a real `no -> yes` transition happened.

## Important note

The current live site state may already be `yes`. In that case, scheduled runs will not notify until the site first goes back to `no` and then later returns to `yes`.
