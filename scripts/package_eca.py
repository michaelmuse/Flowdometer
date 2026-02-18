import zipfile
import os

# Configuration
ORG_ID = "00DRu00000KF7aOMAT"
APP_NAME = "Flowdometer_Local_Test"
FULL_NAME = f"{ORG_ID}:{APP_NAME}"
ZIP_FILENAME = "eca_deploy.zip"

# Source Paths (Source Format)
SRC_ECA = "force-app/main/default/externalClientApps/Flowdometer_Local_Test.eca-meta.xml"
SRC_SETTINGS = "force-app/main/default/extlClntAppOauthSettings/Flowdometer_Local_Test.ecaOauth-meta.xml"

# Target Paths in Zip (MDAPI Format)
# Note: Windows cannot handle these filenames, but the Zip format can.
# We put everything under 'unpackaged/' folder which is standard for deployments
ZIP_PATH_ECA = f"unpackaged/externalClientApps/{FULL_NAME}.eca"
ZIP_PATH_SETTINGS = f"unpackaged/extlClntAppOauthSettings/{FULL_NAME}.ecaOauth"

# Package.xml Content
PACKAGE_XML = f"""<?xml version="1.0" encoding="UTF-8"?>
<Package xmlns="http://soap.sforce.com/2006/04/metadata">
    <types>
        <members>{FULL_NAME}</members>
        <name>ExternalClientApplication</name>
    </types>
    <types>
        <members>{FULL_NAME}</members>
        <name>ExtlClntAppOauthSettings</name>
    </types>
    <version>65.0</version>
</Package>
"""

def create_zip():
    print(f"Creating {ZIP_FILENAME}...")
    with zipfile.ZipFile(ZIP_FILENAME, 'w', zipfile.ZIP_DEFLATED) as zf:
        # Add package.xml
        zf.writestr("unpackaged/package.xml", PACKAGE_XML)
        print("Added package.xml")

        # Add ECA file
        if os.path.exists(SRC_ECA):
            zf.write(SRC_ECA, ZIP_PATH_ECA)
            print(f"Added {SRC_ECA} as {ZIP_PATH_ECA}")
        else:
            print(f"ERROR: Source file not found: {SRC_ECA}")

        # Add Settings file
        if os.path.exists(SRC_SETTINGS):
            zf.write(SRC_SETTINGS, ZIP_PATH_SETTINGS)
            print(f"Added {SRC_SETTINGS} as {ZIP_PATH_SETTINGS}")
        else:
            print(f"ERROR: Source file not found: {SRC_SETTINGS}")

    print("Zip creation complete.")

if __name__ == "__main__":
    create_zip()
