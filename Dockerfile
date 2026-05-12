# syntax=docker/dockerfile:1.7
# ghcr.io/<owner>/gdal-system-python:latest  /  :dev
#
# Python-only sibling of hypertidy/gdal-r-python. Inherits the /opt/gdal-py
# venv from gdal-system — numpy 2.x and the osgeo bindings are already
# linked against /usr/local GDAL/PROJ/GEOS at that layer — then adds the
# same Python geospatial stack that gdal-r-python adds, minus R,
# reticulate, and the jupyter-rsession-proxy that only makes sense
# when an R kernel is present.
#
# Source-vs-binary policy is unchanged from the parent chain:
#   --no-binary (link system GDAL/PROJ/GEOS):
#     rasterio, fiona, pyogrio, shapely, pyproj, geopandas, odc-geo, rioxarray
#   wheels fine (pure Python, Cython, or safely bundled HDF5):
#     pandas, xarray, zarr, fsspec, netCDF4, h5py/h5netcdf, scipy,
#     matplotlib, dask, pyarrow, polars, duckdb, fastparquet, ...
#
# CACHE: BuildKit cache mount on /root/.cache/uv keeps wheels out of image
# layers. UV_LINK_MODE=copy because the cache mount and the venv live on
# different filesystems and uv would otherwise try to hardlink across them.

ARG BASE_IMAGE=ghcr.io/hypertidy/gdal-system:latest
FROM ${BASE_IMAGE}

ARG IMAGE_VARIANT=release

LABEL org.opencontainers.image.source="https://github.com/<owner>/gdal-system-python"
LABEL org.opencontainers.image.description="Python geo stack on hypertidy/gdal-system (no R)"
LABEL org.opencontainers.image.documentation="https://github.com/<owner>/gdal-system-python#readme"

ENV UV_LINK_MODE=copy
ENV PYTHONDONTWRITEBYTECODE=1
ENV GDAL_DATA=/usr/local/share/gdal
ENV PROJ_DATA=/usr/local/share/proj

# ── Sanity: inherited venv is intact, osgeo/numpy aligned ────────────────────
# Cheap check that catches a broken inheritance chain immediately — same
# pattern as gdal-r-python.
RUN <<'EOF' /opt/gdal-py/bin/python
import numpy
from osgeo import gdal, gdal_array
print(f'numpy:      {numpy.__version__}')
print(f'gdal:       {gdal.__version__}')
print(f'gdal_array: {gdal_array.__file__}')
EOF

# python3.12-venv: required by the `build` package to spin up isolated build
# envs. locales: en_US.UTF-8 for jupyter/matplotlib/data-formatting sanity
# (lifted from gdal-r — the only piece of that layer that isn't R-specific).
RUN apt-get update -qq && apt-get install -y --no-install-recommends \
        python3.12-venv \
        locales \
    && locale-gen en_US.UTF-8 \
    && update-locale LANG=en_US.UTF-8 \
    && rm -rf /var/lib/apt/lists/*

ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

# ── Source-built: link system GDAL/PROJ/GEOS ─────────────────────────────────
# Identical list and flags to gdal-r-python. These eight are the ones that
# bind C-level GDAL/PROJ/GEOS symbols; everything else can take wheels.
RUN --mount=type=cache,target=/root/.cache/uv,sharing=locked \
    GDAL_CONFIG=/usr/local/bin/gdal-config \
    PROJ_DIR=/usr/local \
    uv pip install \
        --python /opt/gdal-py/bin/python \
        --no-binary rasterio,fiona,pyogrio,shapely,pyproj,geopandas,odc-geo,rioxarray \
        pyproj shapely fiona rasterio pyogrio geopandas odc-geo rioxarray \
 && find /opt/gdal-py -type d -name __pycache__ -exec rm -rf {} +

# ── Wheels-fine: science / IO / arrow / dask / stac / icechunk / jupyter ────
# Mirrors gdal-r-python's wheel list, with jupyter-rsession-proxy removed
# (it proxies an RStudio Server session — meaningless without R).
RUN --mount=type=cache,target=/root/.cache/uv,sharing=locked \
    uv pip install --python /opt/gdal-py/bin/python \
        build \
        pandas xarray scipy matplotlib cftime pytz tzdata \
        zarr netCDF4 h5netcdf h5py \
        fsspec aiohttp requests s3fs \
        kerchunk virtualizarr rechunker \
        tifffile imagecodecs async-tiff \
        fastparquet \
        pyarrow polars "ibis-framework[duckdb]" \
        stac-geoparquet geoarrow-pyarrow \
        dask distributed cloudpickle toolz partd \
        pystac-client stackstac rio-stac \
        earthaccess pooch \
        icechunk obstore virtual-tiff \
        setuptools wheel cython \
        affine attrs click cligj snuggs pyparsing click-plugins \
        jupyterlab jupyterhub \
        ipytree lonboard pyresample \
        'marimo[sandbox]>=0.23.4' \
        marimo-jupyter-extension \
        rasterix \
 && find /opt/gdal-py -type d -name __pycache__ -exec rm -rf {} + \
 && find /opt/gdal-py -type f -name "*.pyc" -delete

# ── Verify Python stack alignment ────────────────────────────────────────────
COPY scripts/check-python-versions.py /opt/scripts/check-python-versions.py
RUN if [ "${IMAGE_VARIANT}" = "release" ]; then \
        python /opt/scripts/check-python-versions.py; \
    else \
        python /opt/scripts/check-python-versions.py \
            || echo "WARNING: python alignment check failed on dev variant"; \
    fi

# ── MOTD ─────────────────────────────────────────────────────────────────────
# Reuse /etc/gdal-r-ci-motd: the parent gdal-system already wired bashrc to
# source it, so overwriting the file is enough — no /etc/bash.bashrc edit
# needed here.
RUN { \
        echo "── ghcr.io/<owner>/gdal-system-python ──" ; \
        echo "GDAL $(gdal-config --version)   PROJ $(pkg-config --modversion proj)   GEOS $(geos-config --version)" ; \
        echo "Py   $(/opt/gdal-py/bin/python -c 'import sys; print(sys.version.split()[0])')   numpy $(/opt/gdal-py/bin/python -c 'import numpy; print(numpy.__version__)')" ; \
        echo "" ; \
        echo "Docs: https://github.com/<owner>/gdal-system-python" ; \
    } > /etc/gdal-r-ci-motd

WORKDIR /workspace
CMD ["bash"]
