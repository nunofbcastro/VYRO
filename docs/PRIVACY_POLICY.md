# VYRO privacy policy

Last updated: 25 October 2026

## Data stored by VYRO

VYRO stores the profile and goals, meals, cached product lookups, workout plans and sessions, exercise sets, body measurements and movement analysis summaries (counts, durations, observed coverage and events) in a local SQLite database. It also stores, on the device only, the assistant preferences you write, your own recipes, food-photo corrections (which food you chose for a label, as counts, without photos) and local usage counters (for example, photos reviewed and corrections made). VYRO does not provide accounts or cloud sync. Analytics and advertising identifiers are not included.

## Network access

The app connects to Open Food Facts only when the user starts a barcode lookup and the product is not already cached. The request contains the EAN/UPC product identifier and technical request headers. Meal records, profile data, photos, workout videos, and movement landmarks are not sent to Open Food Facts or to an AI service.

## Camera and photo processing

Barcode scanning and optional movement analysis access the camera only after the user starts those screens. Food-photo classification runs on-device. Classification hypotheses are uncertain and do not determine ingredients, serving mass, calories, allergens, technique, or safety. Selected food photos, a second photo or a region you select are held temporarily in memory for review; the app does not retain or upload them. Camera frames for movement analysis are processed in memory and are not saved.

Analysing a video from your gallery is optional. The app copies the chosen video to a temporary file, reads frames from it on the device, and deletes the temporary copy when the analysis ends or the screen is closed. The original video is not changed, and no frames or videos are stored or uploaded.

## User controls

- Export prepares a JSON copy of local records, including assistant preferences, recipes, correction history and local counters, for the user to copy and store.
- Import replaces current VYRO records with a valid export file pasted by the user; each block of assistant and local data is validated before it is written.
- Delete all data clears VYRO profile, goals, product cache, nutrition records, recipes, assistant preferences, correction history, local counters, workout records, movement analyses and measurements on this installation.
- These controls cannot erase copies stored outside VYRO, including an export saved by the user or an operating-system backup.

## Operating system backups

VYRO does not run its own cloud backup and does not read, decrypt or manage operating-system backups. Data stays on the device. The only data the operating system may back up is the local SQLite database (`vyro.sqlite`) and the app settings; the cache, temporary files, photos and videos are never included.

- Android: if Google device backup (Auto Backup) is enabled, Android may include VYRO's local database and settings in your encrypted Google backup and restore them when you reinstall the app or set up a new device. Android makes these cloud backups only when the device is protected by a lock screen.
- iOS: if iCloud device backup is enabled, iOS may include VYRO's local database and settings in your iCloud device backup.

To stop these copies, turn off backup in the system settings (on Android, usually Settings > System > Backup or Settings > Google > Backup, depending on the manufacturer; on iOS, Settings > [your name] > iCloud > iCloud Backup). Turning off device backup does not delete data stored on the device; use "Delete all data" in the app to do that.

## Data sources

Barcode data is attributed to Open Food Facts in the app. The bundled simple-food nutrient reference credits USDA FoodData Central; its data is public domain under CC0. Reference values describe named foods per 100 g and can vary with variety and preparation.

## Contact

This starter project does not yet publish a support contact or legal entity. Add the publisher's contact details before distributing the app publicly.
