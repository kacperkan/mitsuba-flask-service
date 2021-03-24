import mitsuba

mitsuba.set_variant("scalar_rgb")

import os
import shutil
import subprocess
import warnings
from pathlib import Path
from typing import List

import cv2
import numpy as np
from flask import Flask, jsonify, make_response, request
from mitsuba.core import Bitmap, Struct, Thread
from mitsuba.core.xml import load_file, load_string

app = Flask(__name__)

TEMP_IMAGE = "/tmp/temp.exr"
MAPPED_TEMP_IMAGE = "/tmp/temp.png"
TEMP_SCENE = "/tmp/scene.xml"


def _encode_img(scene) -> List[bytes]:
    sensor = scene.sensors()[0]
    scene.integrator().render(scene, sensor)

    film = sensor.film()
    an_img = film.bitmap(raw=True).convert(
        Bitmap.PixelFormat.RGB, Struct.Type.UInt8, srgb_gamma=False
    )
    an_img = np.array(an_img)

    encoded = cv2.imencode(".png", an_img)[1].squeeze().tolist()
    return encoded


def encode_image_from_str(xml_data: str) -> List[bytes]:
    print("Rendering ...")
    scene = load_string(xml_data)
    return _encode_img(scene)


def encode_image_from_file(xml_file: str) -> List[bytes]:
    print("Rendering ...")

    Thread.thread().file_resolver().append(os.path.dirname(xml_file))
    scene = load_file(xml_file)
    return _encode_img(scene)


@app.route("/render", methods=["GET", "POST"])
def render():
    xml_data = request.data
    xml_data = xml_data.decode()
    try:
        encoded = encode_image_from_str(xml_data)
        return jsonify(encoded)
    except Exception as e:
        print(e)
        return make_response(jsonify(error=str(e)))
    finally:
        if os.path.exists(TEMP_SCENE):
            os.remove(TEMP_SCENE)
    return make_response()


@app.route("/render_zip", methods=["GET", "POST"])
def render_zip():
    zip_file = request.files["zip"]

    temporary_file_name = "/tmp/render_data.zip"
    unpack_directory = "/tmp/render_data/"

    zip_file.save(temporary_file_name)
    try:
        print("Unpacking ...")
        os.mkdir(unpack_directory)
        subprocess.call(["unzip", temporary_file_name, "-d", unpack_directory])

        xml_files = list(Path(unpack_directory).rglob("*.xml"))

        if len(xml_files) > 1:
            warnings.warn(
                f"Found XML {len(xml_files)} files in total, taking the first found"
            )

        xml_file = xml_files[0]
        encoded = encode_image_from_file(xml_file.as_posix())
        shutil.rmtree(unpack_directory)
        os.remove(temporary_file_name)

        return jsonify(encoded)
    except Exception as e:
        print(e)
        return make_response(jsonify(error=str(e)))
    finally:
        if os.path.exists(unpack_directory):
            shutil.rmtree(unpack_directory)
        if os.path.exists(temporary_file_name):
            os.remove(temporary_file_name)
    return make_response()


if __name__ == "__main__":
    app.run(host="0.0.0.0", port="8000")
