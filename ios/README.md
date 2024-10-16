# How to build for iOS

## Installation and Setup

The following tools are required to build the App:

- Xcode 14.3+

## Configuration

##### How to work with self-signed SSL certificates?

The App is prepared to work with self-signed certificates, which is interesting when connecting to Cumulocity Edge. By default, the App will allow any requests for the domain name `my.own.iot.com`.

You can configure the allowed domains by modyfing the `Info.plist`. Locate the setting named `Cumulocity Configuration` and add your domain name to `Allowed Domains`.

##### How to add support for languages?

The default language shown in the user interface is `en_US`. Refer to the developer [documentation](https://developer.apple.com/documentation/xcode/adding-support-for-languages-and-regions) to get more information how to add a new language.

Duplicate the `Localizable` `Strings` file and modify the values according to the language your adding. You can not only add more languages but also change how some of the information is presented:

```Console
// Those keys store formats for displaying Alarm related dates.
"alarm_time_printformat" = "MMM dd yyyy, HH:mm";
"alarm_time_locale" = "en_US_POSIX";
```

##### How to change defaults on the App's login view?

To modify the default values shown on the login view check out the soure-code and locate the `Info.plist` file. You'll find a setting named `Cumulocity Configuration` where you can change `Tenant` and `Username` configuration.

#### How to deep link into the App?

A deep link consists of a URI that link to a location within the App. The URL type `c8yalarms` is registered and currently supports the following use cases:

###### Deep link to view a Device using it's id

- `c8yalarms://view/Device?id=<id>`

###### Deep link to view a Device using it's external id

- `c8yalarms://view/Device?externalId=<externalId>`


> The App will not open the deep link if the externalId could not be resolved on your Cumulocity IoT tenant.


## Build

The `Build release candidate` GitHub workflow creates an unsigned `IPA` as well as an Xcode Archive. The `IPA` file can be uploaded to the App Store or deployed to devices using a Mobile-Device-Management (MDM) solution.

The latest release can be found [here](https://github.com/Cumulocity-IoT/cumulocity-alarmapp/releases/latest).

**This build can be distributed, but must be signed before deployed to devices.**

## Code Sign

### Create identifier, certificate and provisioning profiles

In order to re-sign the application, you'll need to prepare your developer account and create an application `Identifier`, a `Certificate` and a `Provisioning Profile`. For more information about configuring your developer account, go to your Apple Developer Account page.

1) Login to developer.apple.com using your Apple Developer account.
2) Open the section about `Certificates, Identifiers & Profiles` and create `App ID` within the `Identifier` section. Choose a `bundle id` and enable `Push Notifications`.
3) On your Mac, open the keychain access and create a signing authority using a `certificate signing request` (.csr).
4) Create a `Certificate`. Select either `In-House and Ad Hoc` or `iOS App Development` depending on if you like to publish on the Apple AppStore or on your corparate store. Upload your `.csr` file and download the certificate. Double click on your `.cert` file to upload the certificate to your keychain.
5) *(optional)* You can export the certificate as a `p12` file. *A .p12 file is a special-formatted, encrypted file that contains the distribution certificate. It’s embedded in your app when you build it*.
6) Create a `Provisioning Profile`. Under Distribution, select an App Store distribution profile for your platform. Afterwards, select your App ID and your distribution certificate.
7) Establish a token-based connection to APNS in order to authorize sending push notifications. See [this](https://developer.apple.com/documentation/usernotifications/setting_up_a_remote_notification_server/establishing_a_token-based_connection_to_apns) article on developer.apple.com for more information. Create a new `Key` adressing `Apple Push Notifications service (APNs)`. You'll have to download the created `.p8` containing the authentication token. This token needs to be configured on your Microsoft Azure Notification Hub.

### Using Fastlane

To sign the `IPA`, it is recommended to use [Fastlane](https://fastlane.tools). See documentation for [Fastlane resign](https://docs.fastlane.tools/actions/resign/) for more infos and config options, for example to change version number, display name, etc. when resigning.

```bash
> fastlane run resign ipa:./AlarmApp.ipa signing_identity:"<Keychain Identity of certificate>" provisioning_profile:<path provisioning profile>
```
