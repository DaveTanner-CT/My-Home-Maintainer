# CloudKit CKShare Production Schema Bootstrap

This one-time workflow exists because TestFlight/App Store builds use CloudKit Production. The system record type `cloudkit.share` cannot be created manually in CloudKit Console. Apple creates it automatically the first time a `CKShare` is successfully saved in the Development environment. After that, deploy the Development schema to Production.

## One-time Apple Developer setup

1. Register the iPhone you will use for the bootstrap under **Certificates, Identifiers & Profiles > Devices** if it is not already registered.
2. Make sure you have an **Apple Development** certificate available to Codemagic.
3. Create a provisioning profile:
   - Profiles > +
   - **iOS App Development**
   - App ID: `org.scriptingforschools.HomeMaintainer`
   - Select the Apple Development certificate
   - Select your iPhone
   - Name: `My Home Keeper CloudKit Development`
4. In Codemagic > Team Settings > Code signing identities:
   - fetch/upload the Apple Development certificate
   - fetch the new Development provisioning profile

## Build the one-time development IPA

Run the Codemagic workflow:

**CloudKit Share Schema Bootstrap (Development)**

Do not publish this build to TestFlight. Download the generated IPA and install it directly on the registered iPhone (for example with iMazing).

## Initialize the CKShare schema

On the development build:

1. Open **My Home Keeper**.
2. Go to **iCloud Sync**.
3. Upload the home to iCloud. This writes to the CloudKit **Development** environment.
4. Go to **Household Sharing**.
5. Tap **Share Household**.
6. Wait for Apple's sharing controller to open. You do not need to send the invitation; the important event is that the share saves successfully.

## Confirm and deploy

1. Open CloudKit Console.
2. Container: `iCloud.org.scriptingforschools.HomeMaintainer`.
3. Environment: **Development**.
4. Schema > Record Types.
5. Confirm `cloudkit.share` now appears.
6. Click **Deploy Schema Changes...** and deploy the additive changes to Production.
7. Return to the normal TestFlight build and retry **Share Household**.

Once `cloudkit.share` is in Production, this bootstrap workflow should no longer be needed.
