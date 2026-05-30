# TestFlight Notes: Chat, Navigation, And Capture UX

## What Changed

This build focuses on making Pensieve easier to use as a daily memory app.

- Navigation is now five tabs: Capture, Memory, Chat, Review, Settings.
- Memory groups Notes, Topics, and Map so users do not miss browse surfaces.
- Review groups Queue, Insights, and Tensions so generated memory has one place to inspect.
- Chat now starts fresh by default and keeps old sessions in history.
- Chat answers can be copied or shared as Markdown with cited note context for use in another LLM.
- URL capture now supports dictated associated notes.
- URL capture can be saved from the keyboard toolbar while the keyboard is open.
- Notes can now be deleted from the Memory notes list or from a note detail
  screen; deleting a note also removes stale generated references to it.

There are no social features in this build.

## What To Try

1. Open Capture and save a text note.
2. Paste a URL, tap `Dictate URL Note`, speak a note, stop dictation, then save the URL.
3. Confirm the URL placeholder disappears when the URL field is focused.
4. Confirm `Save URL` is available above the keyboard while editing the URL or note field.
5. Open Memory and switch between Notes, Topics, and Map.
6. Swipe-delete a disposable note from Notes, then create another disposable
   note and delete it from the note detail trash button.
7. Open Chat, ask a question, then start a new chat and confirm the old session stays in History.
8. Tap Copy and Share on a chat answer; neither action should open a source note.
9. Open Review and switch between Queue, Insights, and Tensions.
10. Quit and reopen the app to confirm chat sessions and generated items persist.

## Useful Feedback

Focus feedback on whether the app feels understandable and lower-friction:

- Is the five-tab navigation clearer than the old `More` overflow?
- Are Memory and Review section names obvious?
- Does fresh Chat avoid old-session clutter?
- Is chat answer export useful for pasting into another LLM?
- Does URL note dictation feel natural?
- Is `Save URL` reachable at the right moment?
- Did any screen feel cluttered, confusing, or hard to find?

## Known Limits

- LLM processing requires a user-supplied Anthropic or OpenAI key.
- Cloud transcription requires the selected provider key; on-device Whisper remains the default.
- Generated outputs depend on the quality and volume of available notes.
- Topic cleanup is meant to create durable review topics, not preserve every raw tag.
- Search/retrieval still uses simple local ranking rather than SQLite full-text search.
