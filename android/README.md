# How to build for Android

## Installation and Setup

The following tools are required to build the App:

- Android Studio Chipmunk or later
- Java 8

## Configuration

##### How to work with self-signed SSL certificates?

Supporting self-signed certificates is currently not supported. Refer to the Android Security [documentation](https://developer.android.com/training/articles/security-ssl).

##### How to add support for languages?

The default language shown in the user interface is `en_US`. The default localiation can be found in `res/values/string.xml`. Refer to the [documentation](https://developer.android.com/guide/topics/resources/localization) to add more languages.

Android uses resource directories with specific naming conventions to hold localized content. The naming convention for resource directories is `res/values-xx`, where `xx` is the two-letter `ISO 639-1` language code for the target language. For example, if you're adding Spanish localization, you would create a directory named `values-es` for Spanish resources. In the new directory you created, copy the default `res/values/strings.xml` and translate the content to the target language.

## Build

The App can be built using the command line or using Android Studio. 

1) Goto project root directory and open command prompt and execute the command `gradlew build`.
2) Alternativly, open the App in Android Studio, it will automatically build the project. 

The created `APK` is located at this path `../app/build/outputs/apk`.

The latest release can be found [here](https://github.com/Cumulocity-IoT/cumulocity-alarmapp/releases/latest).

**This build contains an unsigned APK.**

## Code Sign

Open the App in Android Studio:

- Find the `Build` menu and select `Generate signed bundle/APK.`,
- Select `Apk` and click `next`,
- In keystore path, choose keystore `path(.jks)`, 
-- Create a new keystore if its not present.
- Enter keystore password, key alias and key password,
- Click `next`, select `Release` and click `create`.

Alternativly, use the command line. Goto root project directory and update the `build.gradle` to include the below lines and update the keystore details:

```
android {
    signingConfigs {
        release {
            storeFile file('path/to/your/keystore.jks')
            storePassword 'your_keystore_password'
            keyAlias 'your_key_alias'
            keyPassword 'your_key_password'
        }
    }
    buildTypes {
        release {
            signingConfig signingConfigs.release
        }
    }
}
```

Open command prompt and execute the command `gradlew assembleRelease`.

This will create a signed apk at the path `../app/build/outputs/apk/release`.
