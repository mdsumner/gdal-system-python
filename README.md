# gdal-system-python

Experimental Python-only image built on top of
[`ghcr.io/hypertidy/gdal-system`](https://github.com/hypertidy/gdal-r-ci#gdal-system).

Mirrors the Python stack of `gdal-r-python` without R, reticulate, or the
RStudio-Server JupyterHub proxy. One image, no extras layer — anything beyond
the baseline gets `uv pip install` at runtime.

## Layer-by-layer derivation from `gdal-r-ci`

| Source layer | What we lifted | What we dropped |
| --- | --- | --- |
| `gdal-system` | (parent) — venv at `/opt/gdal-py` with numpy 2.x + osgeo bindings, format libs, Arrow/Parquet apt repo, `uv` on PATH | nothing |
| `gdal-r` | `locales` + `locale-gen en_US.UTF-8` | R, tinytex, pandoc/qpdf/texinfo, the libfontconfig/libharfbuzz/libfribidi stack, libudunits2-dev — all R-side |
| `gdal-r-full` | nothing | the full layer (gdalraster/sf/terra/vapour/gdalcubes) |
| `gdal-r-python` | both `uv pip install` RUNs, `python3.12-venv`, sanity import, `check-python-versions.py` | reticulate install, `RETICULATE_PYTHON`, `RETICULATE_USE_MANAGED_VENV`, `jupyter-rsession-proxy` |
| `gdal-r-python-extras` | nothing | the full layer (R kitchen sink + R-side apt deps) |

## Quick start

NOTE that '<owner>' is left in as a place holder, to build and use this image you'll need to check the names used here. 


```sh
docker run --rm -ti ghcr.io/<owner>/gdal-system-python:latest
```

Lands you in a shell with `gdal-config`, the `/opt/gdal-py/bin/python` interpreter
on PATH, and the full geo stack importable.

## Building locally

```sh
docker build \
    --build-arg BASE_IMAGE=ghcr.io/hypertidy/gdal-system:latest \
    -t gdal-system-python:local .
```

Or against the dev base for a canary:

```sh
docker build \
    --build-arg BASE_IMAGE=ghcr.io/hypertidy/gdal-system:dev \
    --build-arg IMAGE_VARIANT=dev \
    -t gdal-system-python:dev .
```

## Overlaying packages at runtime

```sh
docker run --rm -ti -v $HOME/py-overlay:/opt/py-overlay \
    -e PIP_TARGET=/opt/py-overlay \
    -e PYTHONPATH=/opt/py-overlay \
    ghcr.io/<owner>/gdal-system-python:latest

# inside:
uv pip install --python /opt/gdal-py/bin/python --target /opt/py-overlay <pkg>
```

## Why this exists

A clean reference for "what does the Python half of `gdal-r-python` actually
look like" — useful as a base for cloud-native pipelines, JupyterHub spawners,
or Python-only CI that doesn't want to pull R and ~1 GB of CRAN packages it
will never load. Library alignment guarantees (one PROJ, one GEOS, one GDAL,
one numpy ABI) are inherited from `gdal-system` and remain intact.

## Related

- [hypertidy/gdal-r-ci](https://github.com/hypertidy/gdal-r-ci) — the parent
  chain, including `gdal-system` which is the base for this image.
