# yt-dlp helper scripts

Small command-line tools for downloading and converting media. The playbook installs
them to `~/.local/bin` (on `PATH`) when `yt-dlp` is in a Homebrew list:

```bash
ansible-playbook -i inventory.yml setup.yml --tags yt-dlp
```

To add a script: put it in this folder, make it executable and add its name to
`ytdlp_scripts` in `vars/main.yml`.

Requirements: `yt-dlp`, `ffmpeg`, `jq`, `curl` (all from Homebrew; `ffmpeg` and `yt-dlp`
are in `homebrew_packages_local` on this machine). The yt-dlp user config
(`~/.config/yt-dlp/config`, from `ytdlp_options`) reads cookies from Brave.

| Tool | Does |
|---|---|
| [`patreon-collection`](#patreon-collection) | Downloads all posts of a Patreon collection (or one post), in order, with tags |
| [`to-mp3`](#to-mp3) | Converts videos to mp3 and keeps the music tags |

## patreon-collection

```text
patreon-collection <collection or post URL, or collection ID> [--flat] [--videos-only] [--mp3] [yt-dlp options...]
```

The options can be in any order. Arguments that are not the URL or one of the options
below go to yt-dlp (for example `-f`, `--limit-rate`, `--simulate`).

| Option | Effect |
|---|---|
| (none) | One folder per post: `<collection>/NNN <post title>/<files>` |
| `--flat` | One folder for all: `<collection>/NNN <file>`. Good for video-only collections |
| `--videos-only` | Skip the non-media attachments (PDF, tabs, images). Audio attachments (mp3, m4a) still download, because yt-dlp gets them |
| `--mp3` | Also write an mp3 of each video, next to it (uses `to-mp3`) |
| `-h`, `--help` | Show usage |

`NNN` is the position of the post in the collection.

One post: give the post URL (`https://www.patreon.com/<creator>/posts/<slug>-<id>`, with or
without `?collection=...`). It downloads the video and all attachments to
`./<post title>/<files>`, without `NNN`. Album tag = post title. `--flat` has no effect.
A bare number is always a collection ID.

Examples:

```bash
cd ~/Documents/ear_training
patreon-collection https://www.patreon.com/collection/878272 --flat --mp3
patreon-collection https://www.patreon.com/collection/1570882 -f 'bv*[height<=1080]+ba'
patreon-collection https://www.patreon.com/KoreyHicksGuitar/posts/autumn-leaves-1-139552148 --mp3
```

What it gets from each post:

| Content | Downloaded by | File name |
|---|---|---|
| Video (Patreon-hosted or YouTube embed) | yt-dlp | video title |
| Audio/video attachment (mp3, m4a, ...) | yt-dlp | original file name |
| Other attachment (pdf, gp, jpg, ...) | curl, Patreon API | original file name (`<media id>.<ext>` if Patreon has no name) |
| Post cover image / video thumbnail | not downloaded | |
| Links in the post text (Google Drive/Docs, Dropbox, ...) | not downloaded | listed in `links.txt` as `NNN <link>` |

Tags (yt-dlp, `--embed-metadata`): album = collection title, track = see below,
title = file name or video title, artist = creator. Players (DS audio, Jellyfin,
VLC, Spotify local files) group each collection as one album, in order.

Track number = `NNN` plus the extra media items of the posts before it. A post with
several media items (yt-dlp sees them as a playlist) numbers them in Patreon order, one
each. So track = `NNN` until the first post with more than one item; after it, track is
higher than `NNN`. The mp3 from `--mp3` keeps the track of its video.

Resume and errors:

- Run the same command again to resume. `archive.txt` skips downloaded media; existing
  attachments and mp3s are skipped.
- Use the same layout (`--flat` or not) on resume. `archive.txt` also skips videos that
  are in the other layout.
- Posts that fail go to `failed.txt` with the reason (`no media in post` for text-only
  posts and polls, `yt-dlp error` for broken embeds). The run continues. The file is
  removed when nothing failed.
- A post with only external links is not a failure: check `links.txt` and get those
  files by hand (a Google Slides/Docs link shared by link exports with
  `https://docs.google.com/presentation/d/<id>/export/pdf`).

Notes:

- macOS asks once for Keychain access to "Brave Safe Storage". You must be logged in to
  Patreon in Brave.
- `cannot read Brave cookies` with `could not find brave cookies database`: macOS blocks
  the terminal from Brave's data folder. Give the terminal app Full Disk Access (System
  Settings → Privacy & Security → Full Disk Access) and restart it.
- The script reads the Brave cookies once into a temporary file (mode 600) and deletes
  it on exit, also on Ctrl-C.
- Each post starts a new yt-dlp process, so a post takes some seconds before the
  download starts.

## to-mp3

```text
to-mp3 [-q N] <file or folder>...
```

| Option | Effect |
|---|---|
| `-q N` | LAME VBR quality, `0` (best) to `9` (smallest). Default `2` (about 170-210 kbps; less for simple audio) |
| folder | Converts the videos in it (mkv, mp4, webm, mov, m4v, avi). Not recursive |
| file | Converts that file (any format with an audio stream, except mp3) |

- Writes `<name>.mp3` next to the source. Skips a file when its mp3 already exists.
- Keeps the tags title, artist, album, album_artist, track, date, genre. Drops the rest.
- Exit code 1 if a conversion failed; the other files still convert.

Examples:

```bash
to-mp3 ~/Documents/ear_training/'120 Ear Training Exercises'
to-mp3 -q 5 lesson.mkv
```
