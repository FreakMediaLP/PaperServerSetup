import requests


def send_request(url):
    try:
        temp = requests.get(url)
        return temp
    except Exception as error:
        print(f"An error occurred while requesting \"{url}\": {error}\nThe program will be terminated")
        exit()


def download_build(file_name, file_version, build):
    papermc_url = f"https://api.papermc.io/v2/projects/paper/versions/{file_version}/builds/{build}/downloads/{file_name}"

    print(f"Downloading paper.jar for Minecraft version \"{file_version}\" latest build [{build}]...")
    jar_response = send_request(papermc_url)

    if jar_response.ok:
        with open("paper.jar", "wb") as jar_file:
            jar_file.write(jar_response.content)
        print("Successfully downloaded paper.jar")
    else:
        print(f"Failed to download paper.jar from \"{papermc_url}\" status_code: {jar_response.status_code}")


minecraft_version = input("Minecraft version: ")
response = send_request(f"https://api.papermc.io/v2/projects/paper/versions/{minecraft_version}/builds")

if response.ok and "builds" in response.json():
    builds = [build["build"] for build in response.json()["builds"] if build["channel"] == "default"]
    latest_build = builds[-1] if builds else None

    if latest_build is not None:
        jar_name = f"paper-{minecraft_version}-{latest_build}.jar"
        download_build(jar_name, minecraft_version, latest_build)
    else:
        print(f"No stable build for Minecraft version \"{minecraft_version}\" found")
        search_experimental = input("Do you want to look for experimental builds? (Y/n): ").strip().lower()
        if search_experimental in ["", "y", "Y"]:
            experimental_builds = [build["build"] for build in response.json()["builds"] if build["channel"] == "experimental"]
            latest_experimental_build = experimental_builds[-1] if experimental_builds else None

            if latest_experimental_build is not None:
                print(f"Experimental build for Minecraft version \"{minecraft_version}\" found")
                jar_name = f"paper-{minecraft_version}-{latest_experimental_build}.jar"
                download_build(jar_name, minecraft_version, latest_experimental_build)
            else:
                print(f"No experimental build for Minecraft version \"{minecraft_version}\" found")
else:
    print(f"Unable to request builds for Minecraft version \"{minecraft_version}\" status_code: {response.status_code}")