import SwiftUI
import Contacts
import ContactsUI

struct VendorContactImport {
    let businessName: String
    let contactName: String
    let phone: String
    let email: String
    let website: String
    let address: String
}

struct ContactImportPresenter: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let onSelect: (VendorContactImport) -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIViewController(context: Context) -> UIViewController {
        let controller = UIViewController()
        controller.view.backgroundColor = .clear
        return controller
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        context.coordinator.parent = self

        guard isPresented else { return }
        guard context.coordinator.presentedPicker == nil else { return }
        guard uiViewController.viewIfLoaded?.window != nil else {
            // The representable can be updated before its host form is on-screen.
            // Try again on the next run-loop turn without changing the binding.
            DispatchQueue.main.async {
                context.coordinator.requestPresentation(from: uiViewController)
            }
            return
        }

        context.coordinator.requestPresentation(from: uiViewController)
    }

    final class Coordinator: NSObject, CNContactPickerDelegate {
        var parent: ContactImportPresenter
        weak var presentedPicker: CNContactPickerViewController?

        init(parent: ContactImportPresenter) {
            self.parent = parent
        }

        func requestPresentation(from host: UIViewController) {
            guard parent.isPresented else { return }
            guard presentedPicker == nil else { return }
            guard host.viewIfLoaded?.window != nil else { return }

            let picker = CNContactPickerViewController()
            picker.delegate = self
            picker.displayedPropertyKeys = [
                CNContactOrganizationNameKey,
                CNContactGivenNameKey,
                CNContactMiddleNameKey,
                CNContactFamilyNameKey,
                CNContactPhoneNumbersKey,
                CNContactEmailAddressesKey,
                CNContactUrlAddressesKey,
                CNContactPostalAddressesKey
            ]
            presentedPicker = picker
            host.present(picker, animated: true)
        }

        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            let imported = VendorContactMapper.importedValues(from: contact)
            presentedPicker = nil

            // CNContactPicker dismisses itself. We only update the existing Vendor form;
            // no SwiftUI sheet is toggled here, so the Vendor form remains on screen.
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.parent.onSelect(imported)
                self.parent.isPresented = false
            }
        }

        func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
            presentedPicker = nil
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.parent.isPresented = false
                self.parent.onCancel()
            }
        }
    }
}

struct VendorContactEditor: UIViewControllerRepresentable {
    let vendor: Vendor
    let onComplete: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIViewController(context: Context) -> UINavigationController {
        let contact = VendorContactMapper.contact(from: vendor)
        let controller = CNContactViewController(forNewContact: contact)
        controller.contactStore = CNContactStore()
        controller.delegate = context.coordinator
        controller.allowsEditing = true
        controller.title = "Add to Contacts"
        return UINavigationController(rootViewController: controller)
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) { }

    final class Coordinator: NSObject, CNContactViewControllerDelegate {
        let parent: VendorContactEditor

        init(parent: VendorContactEditor) {
            self.parent = parent
        }

        func contactViewController(_ viewController: CNContactViewController, didCompleteWith contact: CNContact?) {
            DispatchQueue.main.async { [parent] in
                parent.onComplete()
            }
        }
    }
}

enum VendorContactMapper {
    static func displayName(for contact: CNContact) -> String {
        let formatted = CNContactFormatter.string(from: contact, style: .fullName) ?? ""
        return formatted.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func importedValues(from contact: CNContact) -> VendorContactImport {
        let personName = displayName(for: contact)
        let organization = contact.organizationName.trimmingCharacters(in: .whitespacesAndNewlines)
        let businessName = organization.isEmpty ? personName : organization
        let contactName = organization.isEmpty ? "" : personName
        let phone = contact.phoneNumbers.first?.value.stringValue ?? ""
        let email = contact.emailAddresses.first.map { String($0.value) } ?? ""
        let website = contact.urlAddresses.first.map { String($0.value) } ?? ""
        let address: String = {
            guard let postal = contact.postalAddresses.first?.value else { return "" }
            return CNPostalAddressFormatter.string(from: postal, style: .mailingAddress)
                .replacingOccurrences(of: "\n", with: ", ")
        }()
        return VendorContactImport(
            businessName: businessName,
            contactName: contactName,
            phone: phone,
            email: email,
            website: website,
            address: address
        )
    }

    static func contact(from vendor: Vendor) -> CNMutableContact {
        let contact = CNMutableContact()
        let trimmedBusiness = vendor.businessName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedContact = vendor.contactName.trimmingCharacters(in: .whitespacesAndNewlines)

        if !trimmedBusiness.isEmpty { contact.organizationName = trimmedBusiness }
        if !trimmedContact.isEmpty {
            let parts = trimmedContact.split(separator: " ").map(String.init)
            if parts.count > 1 {
                contact.givenName = parts.dropLast().joined(separator: " ")
                contact.familyName = parts.last ?? ""
            } else {
                contact.givenName = trimmedContact
            }
        }
        if !vendor.category.isEmpty { contact.jobTitle = vendor.category }
        if !vendor.phone.isEmpty {
            contact.phoneNumbers = [CNLabeledValue(label: CNLabelWork, value: CNPhoneNumber(stringValue: vendor.phone))]
        }
        if !vendor.email.isEmpty {
            contact.emailAddresses = [CNLabeledValue(label: CNLabelWork, value: vendor.email as NSString)]
        }
        if !vendor.website.isEmpty {
            contact.urlAddresses = [CNLabeledValue(label: CNLabelURLAddressHomePage, value: vendor.website as NSString)]
        }
        if !vendor.address.isEmpty {
            let postal = CNMutablePostalAddress()
            postal.street = vendor.address
            contact.postalAddresses = [CNLabeledValue(label: CNLabelWork, value: postal)]
        }
        if !vendor.notes.isEmpty { contact.note = vendor.notes }
        return contact
    }
}
