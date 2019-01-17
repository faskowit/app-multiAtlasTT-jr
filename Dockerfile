FROM brainlife/freesurfer:6.0.0
MAINTAINER Joshua Faskowitz <jfaskowi@iu.edu>

RUN apt-get update && apt-get install -y python python-pip wget
RUN pip install nibabel six
