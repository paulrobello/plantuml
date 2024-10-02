"""Lambda function code for generating SVG and PNG from PlantUML source."""

import subprocess
import tempfile
import os
import base64
from typing import Any

from aws_lambda_powertools import Logger
from aws_lambda_powertools.utilities.data_classes import (
    LambdaFunctionUrlEvent,
    event_source,
)
from aws_lambda_powertools.utilities.typing import LambdaContext

logger = Logger()

API_KEY = os.environ.get("API_KEY")


def generate_image_from_plantuml(plantuml_string: str, image_format: str = "svg") -> str:
    """Generate SVG content from PlantUML source string."""
    # print(plantuml_string)

    if image_format not in ["png", "svg"]:
        image_format = "svg"
    # Create a temporary file for the PlantUML source
    with tempfile.NamedTemporaryFile(delete=False, suffix=".txt") as tmpfile:
        plantuml_file_path = tmpfile.name
        # print(plantuml_file_path)

        tmpfile.write(plantuml_string.encode("utf-8"))
        tmpfile.flush()

        # Define the output SVG file path
        image_output_path = plantuml_file_path.replace(".txt", f".{image_format}")
        # print(svg_output_path)

        # Path to your PlantUML.jar file (adjust as necessary)
        plantuml_jar_path = "/opt/java/lib/plantuml.jar"

        # Construct the PlantUML command
        plantuml_command = [
            "/opt/java/lib/bin/java",
            "-jar",
            plantuml_jar_path,
            f"-t{image_format}",
            plantuml_file_path,
            "-o",
            "/tmp",
        ]

        # Execute the command
        subprocess.run(plantuml_command, check=True)

        if image_format == "png":
            with open(image_output_path, mode="rb") as image_file:
                image_content = base64.b64encode(image_file.read()).decode("utf-8")
        else:
            # Read and return the SVG content
            with open(image_output_path, mode="r", encoding="utf-8") as svg_file:
                image_content = svg_file.read()

        # Clean up temporary files
        os.remove(plantuml_file_path)
        os.remove(image_output_path)

        return image_content


@event_source(data_class=LambdaFunctionUrlEvent)
@logger.inject_lambda_context(log_event=True)
def lambda_handler(
        event: LambdaFunctionUrlEvent, context: LambdaContext  # type: ignore
) -> dict[str, Any]:
    """Lambda function entry point."""
    # check x-api-key header if API_KEY is set
    if API_KEY and (
            "x-api-key" not in event["headers"] or event["headers"]["x-api-key"] != API_KEY
    ):
        return {"statusCode": 403, "body": "Forbidden"}

    image_format: str = "svg"
    if "queryStringParameters" in event:
        if "format" in event["queryStringParameters"]:
            image_format = event["queryStringParameters"]["format"].lower().strip()
            if image_format not in ["png", "svg"]:
                return {"statusCode": 400, "body": "Invalid format"}

    plantuml_input = event["body"]
    if event["isBase64Encoded"]:
        plantuml_input = base64.b64decode(plantuml_input).decode("utf-8")
    # logger.info(plantuml_input)

    image_output = generate_image_from_plantuml(plantuml_input, image_format)
    if image_format == "svg":
        context_type = "image/svg+xml"
    else:
        context_type = "image/png"

    return {
        "statusCode": 200,
        "body": image_output,
        "headers": {"Content-Type": context_type},
        "isBase64Encoded": image_format == "png"
    }
