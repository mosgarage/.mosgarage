from os import path

from setuptools import find_packages, setup


setup(
    name="flask-rest-api",
    package_dir={"": "src"},
    packages=find_packages("src"),
    package_data={},
    include_package_data=True,
    version="0.0.1",
    long_description="...",
    long_description_content_type="text/markdown",
    keywords=["python"],
    classifiers=["Development Status :: Beta", "Programming Language :: Python :: 3.8"],
)
