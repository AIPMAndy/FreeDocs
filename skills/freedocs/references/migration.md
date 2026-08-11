# DOCX migration

## Preserve the source

Keep the export folder read-only. Build an inventory outside it containing:

- relative path;
- size;
- SHA-256;
- approval status;
- target collection;
- sensitivity/publication decision.

Do not infer that all files in a directory are approved for upload.

## Pilot first

Select one representative DOCX with headings, long text, images, tables, links, and non-ASCII filenames. Import it through the same browser and public URL that the owner will use.

Pass criteria:

- Outline navigates to a real document;
- title and body are readable;
- all expected media load;
- search finds a distinctive title phrase and body phrase;
- collection placement is correct;
- permissions match the intended audience.

## Batch ledger

Use this schema:

| source_path | sha256 | target_collection | result_url | title_ok | body_ok | media_ok | searchable | duplicate | decision |
|---|---|---|---|---|---|---|---|---|---|

Import in small batches. Reconcile source count, created-document count, and searchable-document count after each batch. A file-chooser completion event is not proof that a document exists.

## Duplicate handling

- Freeze further imports if counts unexpectedly increase.
- Group candidates by normalized title, but compare source path, hash, body, and target collection.
- Do not delete automatically. Same-title documents may be intentionally distinct.
- Record `KEEP`, `MERGE`, `DELETE_APPROVED`, or `UNRESOLVED`; only execute deletion with explicit approval and a backup.

## Sharing model

- Collection URL: authenticated workspace navigation.
- Document URL: authenticated document editing/viewing.
- Public share URL: signed-out reading when enabled.
- Member invitation: authenticated editing, viewing, or comments based on role.

Test each required path separately. Ensure public pages do not reveal private siblings, internal comments, unpublished drafts, or administrative navigation.
