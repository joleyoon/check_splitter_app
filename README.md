# Check Splitter

Native SwiftUI iOS app for splitting a restaurant check from a photo.

## What it does

- Takes a check photo or imports one from the photo library.
- Uses Apple's on-device Vision OCR to find likely line items and prices.
- Lets you add/edit people and manual items.
- Lets each item be assigned to one or more people.
- Splits shared items, tax, and tip proportionally by each person's item subtotal.

## Run

Open `CheckSplitter.xcodeproj` in Xcode, select an iPhone simulator or device, and run the `CheckSplitter` scheme.

This app uses `UIImagePickerController` for camera/photo input and `VNRecognizeTextRequest` for OCR. A physical device is best for testing the camera flow.

## Notes

The OCR parser is intentionally conservative. Receipt formats vary heavily, so the app imports obvious `item name + price` lines and expects the user to review the result before settling up.
