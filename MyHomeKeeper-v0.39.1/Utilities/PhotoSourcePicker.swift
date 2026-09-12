import SwiftUI
import PhotosUI
import UIKit
import AVFoundation

struct PhotoSourceButton<Label: View>: View {
    let onPhoto: (Data) -> Void
    private let label: () -> Label

    init(onPhoto: @escaping (Data) -> Void, @ViewBuilder label: @escaping () -> Label) {
        self.onPhoto = onPhoto
        self.label = label
    }

    @State private var showSourceOptions = false
    @State private var showCamera = false
    @State private var showPhotoLibrary = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var cameraAlertMessage: String?

    var body: some View {
        Button {
            showSourceOptions = true
        } label: {
            label()
        }
        .confirmationDialog("Add Photo", isPresented: $showSourceOptions, titleVisibility: .visible) {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button("Take Photo") {
                    presentCameraAfterDialogDismisses()
                }
            }
            Button("Choose from Photo Library") {
                presentPhotoLibraryAfterDialogDismisses()
            }
            Button("Cancel", role: .cancel) { }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPhotoPicker(isPresented: $showCamera) { data in
                onPhoto(data)
            }
            .ignoresSafeArea()
        }
        .photosPicker(isPresented: $showPhotoLibrary, selection: $selectedPhoto, matching: .images)
        .onChange(of: selectedPhoto) { _, newValue in
            guard let newValue else { return }
            Task {
                if let data = try? await newValue.loadTransferable(type: Data.self) {
                    await MainActor.run { onPhoto(data) }
                }
                await MainActor.run { selectedPhoto = nil }
            }
        }
        .alert("Camera Unavailable", isPresented: Binding(
            get: { cameraAlertMessage != nil },
            set: { if !$0 { cameraAlertMessage = nil } }
        )) {
            Button("OK", role: .cancel) { cameraAlertMessage = nil }
        } message: {
            Text(cameraAlertMessage ?? "The camera is not available.")
        }
    }

    private func presentCameraAfterDialogDismisses() {
        Task { @MainActor in
            // Let the confirmation dialog finish dismissing before starting another presentation.
            try? await Task.sleep(nanoseconds: 250_000_000)
            await requestCameraAndPresentIfAllowed()
        }
    }

    private func presentPhotoLibraryAfterDialogDismisses() {
        Task { @MainActor in
            // Avoid competing presentations between the confirmation dialog and Photos picker.
            try? await Task.sleep(nanoseconds: 250_000_000)
            showPhotoLibrary = true
        }
    }

    @MainActor
    private func requestCameraAndPresentIfAllowed() async {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            cameraAlertMessage = "This device does not have an available camera."
            return
        }

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            showCamera = true

        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            if granted {
                showCamera = true
            } else {
                cameraAlertMessage = "Camera access is off. Enable Camera access for My Home Keeper in Settings to take photos in the app."
            }

        case .denied, .restricted:
            cameraAlertMessage = "Camera access is off. Enable Camera access for My Home Keeper in Settings to take photos in the app."

        @unknown default:
            cameraAlertMessage = "The camera is currently unavailable."
        }
    }
}

struct CameraPhotoPicker: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let onPhoto: (Data) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(isPresented: $isPresented, onPhoto: onPhoto)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.allowsEditing = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) { }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        private var isPresented: Binding<Bool>
        private let onPhoto: (Data) -> Void
        private var hasFinished = false

        init(isPresented: Binding<Bool>, onPhoto: @escaping (Data) -> Void) {
            self.isPresented = isPresented
            self.onPhoto = onPhoto
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            finishPresentation()
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            guard !hasFinished else { return }
            hasFinished = true

            if let image = info[.originalImage] as? UIImage,
               let data = image.jpegData(compressionQuality: 0.9) ?? image.pngData() {
                // Capture the image first, then close only the camera presentation.
                onPhoto(data)
            }

            DispatchQueue.main.async { [weak self] in
                self?.isPresented.wrappedValue = false
            }
        }

        private func finishPresentation() {
            guard !hasFinished else { return }
            hasFinished = true
            DispatchQueue.main.async { [weak self] in
                self?.isPresented.wrappedValue = false
            }
        }
    }
}
