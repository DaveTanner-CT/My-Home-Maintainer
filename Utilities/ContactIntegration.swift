import SwiftUI
import Contacts
import ContactsUI

struct ContactImportPicker: UIViewControllerRepresentable {
    let onSelect: (CNContact) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        picker.displayedPropertyKeys = [
            CNContactOrganizationNameKey,
            CNContactGivenNameKey,
            CNContactFamilyNameKey,
            CNContactPhoneNumbersKey,
            CNContactEmailAddressesKey,
            CNContactUrlAddressesKey,
            CNContactPostalAddressesKey
        ]
        return picker
    }

    func updateUIViewController(_ uiViewController: CNContactPickerViewController, context: Context) { }

    final class Coordinator: NSObject, CNContactPickerDelegate {
        let parent: ContactImportPicker
        init(parent: ContactImportPicker) { self.parent = parent }

        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            parent.onSelect(contact)
        }

        func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
            parent.dismiss()
        }
    }
}

struct VendorContactEditor: UIViewControllerRepresentable {
    let vendor: Vendor
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIViewController(context: Context) -> UINavigationController {
        let contact = VendorContactMapper.contact(from: vendor)
        let controller = CNContactViewController(forNewContact: contact)
        controller.contactStore = CNContactStore()
        controller.delegate = context.coordinator
        controller.allowsEditing = true
        let nav = UINavigationController(rootViewController: controller)
        return nav
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) { }

    final class Coordinator: NSObject, CNContactViewControllerDelegate {
        let parent: VendorContactEditor
        init(parent: VendorContactEditor) { self.parent = parent }

        func contactViewController(_ viewController: CNContactViewController, didCompleteWith contact: CNContact?) {
            parent.dismiss()
        }
    }
}

enum VendorContactMapper {
    static func displayName(for contact: CNContact) -> String {
        let formatted = CNContactFormatter.string(from: contact, style: .fullName) ?? ""
        return formatted.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func importedValues(from contact: CNContact) -> (businessName: String, contactName: String, phone: String, email: String, website: String, address: String) {
        let personName = displayName(for: contact)
        let organization = contact.organizationName.trimmingCharacters(in: .whitespacesAndNewlines)
        let businessName = organization.isEmpty ? personName : organization
        let contactName = organization.isEmpty ? "" : personName
        let phone = contact.phoneNumbers.first?.value.stringValue ?? ""
        let email = contact.emailAddresses.first?.value as String? ?? ""
        let website = contact.urlAddresses.first?.value as String? ?? ""
        let address: String = {
            guard let postal = contact.postalAddresses.first?.value else { return "" }
            return CNPostalAddressFormatter.string(from: postal, style: .mailingAddress)
                .replacingOccurrences(of: "\n", with: ", ")
        }()
        return (businessName, contactName, phone, email, website, address)
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
