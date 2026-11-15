"""Patch scaffold created by `flutter create` with EduHub's native G2 activity.
No network access or third-party app bytes are used by this script.
"""
from pathlib import Path
import shutil
import xml.etree.ElementTree as ET

root=Path(__file__).resolve().parents[1]
android=root/'android'
manifest=android/'app/src/main/AndroidManifest.xml'
if not manifest.exists():
    raise SystemExit('Android scaffold missing. Run: flutter create --platforms=android --org vn.eduhub .')
source=root/'native/MainActivity.kt'
target=android/'app/src/main/kotlin/vn/eduhub/eduhub/MainActivity.kt'
target.parent.mkdir(parents=True,exist_ok=True)
shutil.copy2(source,target)
# Remove generated activities with unexpected packages, if present.
for duplicate in (android/'app/src/main/kotlin').rglob('MainActivity.kt'):
    if duplicate!=target:
        duplicate.unlink()

namespace='http://schemas.android.com/apk/res/android'
ET.register_namespace('android',namespace)
tree=ET.parse(manifest)
main=tree.getroot()
application=main.find('application')
assert application is not None
application.set('{%s}label'%namespace,'EduHub')
application.set('{%s}allowBackup'%namespace,'false')
application.set('{%s}usesCleartextTraffic'%namespace,'false')
if not any(child.tag=='uses-permission' and child.get('{%s}name'%namespace)=='android.permission.INTERNET' for child in main):
    ET.SubElement(main,'uses-permission',{'{%s}name'%namespace:'android.permission.INTERNET'})
tree.write(manifest,encoding='utf-8',xml_declaration=True)
print('EduHub native G2 activity installed and AndroidManifest patched.')
