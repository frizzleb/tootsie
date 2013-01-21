Tootsie
=======

Tootsie (formerly called Tranz) is a simple, robust, scalable audio/video/image transcoding/modification application.

Tootsie can transcode audio, video and images between different formats, and also perform basic manipulations such as photo scaling and cropping, for generating thumbnails and photos at different resolutions.

Overview
--------

Tootsie is divided into multiple independent parts:

### API web worker

The API providers a simple way to submit new jobs.

### Job processor

The job manager accepts new transcoding jobs and executes the. The job manager uses a persistent queue, and supports either local file-based queues (not recommended and mostly suitable for testing), AMQP queues (eg., RabbitMQ) and Amazon Simple Queue Service (aka SQS).

### Transcoding processors

There are multiple processors. External transcoding tools such as ffmpeg and ImageMagick are used to perform the actual transcoding.

### Storage

Tootsie can read files via HTTP[S], and can upload data via HTTP[S] POSTs. In addition, Amazon S3 buckets are also supported.

Dependencies
------------

* Ruby 1.8.7 or later (1.9.3 recommended).
* Unix-like system (no Windows support currently).
* **For video jobs**
  * FFmpeg
  * id3v2 (optional)
* **For image jobs**
  * ImageMagick
  * Exiv2
  * pngcrush (optional)

### Optional

* Amazon S3 account, for loading and storage of files.
* AMQP-compliant server (such as RabbitMQ) or Amazon Simple Queue Service for internal task queue management.

Installation
------------

`gem install tootsie`

Running
-------

Create a configuration, eg. `tootsie.conf`:

    --- 
      queue:
        adapter: sqs
        queue: tootise
      aws_access_key_id: <your Amazon key>
      aws_secret_access_key: <your Amazon secret>
      pid_path: <where to write pid file>
      log_path: <where to write log file>
      worker_count: <number of workers>

Start the task manager with `tootsie -c tootsie.conf`.

Now create a rackup file, and call it `config.ru`:

    require 'tootsie'
    Tootsie::Application.new.configure!('tootsie.conf')
    run Tootsie::WebService

To run the web service, you will need a Rack-compatible web server, such as Unicorn or Thin. To start with Thin on port 9090:

    $ thin --daemonize --rackup config.ru --port 9090 start

Jobs may now be posted to the web service API. For example:

    $ cat << END | curl -d @- http://localhost:9090/job
    {
      "type": "video",
      "notification_url": "http://example.com/transcoder_notification",
      "params": {
        "input_url": "http://example.com/test.3gp",
        "versions": {
          "target_url": "s3:mybucket/test.mp4?acl=public_read",
          "audio_sample_rate": 44100,
          "audio_bitrate": 64000,
          "format": "flv",
          "content_type": "video/x-flv"
        }
      }
    }
    END

Configuration
-------------

The configuration is a YAML document with the following keys:

    aws_access_key_id: <your Amazon key>
    aws_secret_access_key: <your Amazon secret>
    pid_path: <where to write pid file>
    log_path: <where to write log file>
    worker_count: <number of workers>
    queue:
      <... queue options ...>

The queue options is a hash with a key `adapter` telling Tootsie which queue implementation to use.

The `sqs` adapter takes the following options:

    queue: <name of queue, defaults to 'tootsie'>
    max_backoff: <max seconds to wait when queue is empty, defaults to 2>

For the `amqp` adapter:

    queue: <name of queue, defaults to 'tootsie'>
    host_name: <host name of AMQP server, defaults to localhost>
    max_backoff: <max seconds to wait when queue is empty, defaults to 2>

For the `file` adapter:

    root: <directory to store files>

Note that when running a large number of workers, you should increase the backoff interval to avoid incurring a lot of queue requests.

API
---

To schedule jobs, one uses the REST service:

* POST `/job`: Schedule a job. Returns 201 if the job was created.
* GET `/status`: Get current processing status as a JSON hash.

The job must be posted as an JSON hash with the content type `application/json`. Common to all job scheduling POSTs are these keys:

* `type`: Type of job. See sections below for details.
* `notification_url`: Optional notification URL. Progress (including completion and failure) will be reported using POSTs.
* `retries`: Maximum number of retries, if any. Defaults to 5.

Job-specific parameters are provided in the key `params`.

The Tootsie daemon pops jobs from a queue and processes them. Each job specifies an input, an output, and transcoding parameters. Optionally the job may also specify a notification URL which is invoked to inform the caller about job progress.

Supported inputs at the moment:

* HTTP resource. Currently only public (non-authenticated) resources are supported.
* Amazon S3 bucket resource. S3 buckets must have the appropriate ACLs so that Tootsie can read the files; if the input file is not public, Tootsie must be run with an AWS access key that is granted read access to the file.

Supported outputs:

* HTTP resource. The encoded file will be `POST`ed to a URL.
* Amazon S3 bucket resource. Tootsie will need write permissions to any S3 buckets.

Each job may have multiple outputs given a single input. Designwise, the reason for doing this -- as opposed to requiring that the client submit multiple jobs, one for each output -- is twofold:

1. It allows the job to cache the input data locally for the duration of the job, rather than fetching it multiple times. One could suppose that multiple jobs could share the same cached input, but this would be awkward in a distributed setting where each node has its own file system; in such a case, a shared storage mechanism (file system, database or similar) would be needed.

2. It allows the client to be informed when *all* transcoded versions are available, something which may drastically simplify client logic. For example, a web application submitting a job to produce multiple scaled versions of an image may only start showing these images when all versions have been produced. To know whether all versions have been produced, it needs to maintain state somewhere about the progress. Having a single job produce all versions means this state can be reduced to a single boolean value.

When using multiple outputs per job one should keep in mind that this reduces job throughput, requiring more concurrent job workers to be deployed.

FFmpeg and ImageMagick are invoked for each job to perform the transcoding. These are abstracted behind set of generic options specifying format, codecs, bit rate and so on.

### Video transcoding jobs

Video jobs have the `type` key set to either `video`, `audio`. Currently, `audio` is simply an alias for `video` and handled by the same pipeline. The key `params` must be set to a hash with these keys:

* `input_url`: URL to input file, either an HTTP URL or an S3 URL (see below).
* `versions`: Either a hash or an array of such hashes, each with the following keys:
  * `target_url`: URL to output resource, either an HTTP URL which accepts POSTs, or an S3 URL.
  * `thumbnail`: If specified, a thumbnail will be generated based on the options in this hash with the following keys:
    * `target_url`: URL to output resource, either an HTTP URL which accepts POSTs, or an S3 URL.
    * `width`: Desired width of thumbnail, defaults to output width.
    * `height`: Desired height of thumbnail, defaults to output height.
    * `at_seconds`: Desired point (in seconds) at which the thumbnail frame should be captured. Defaults to 50% into stream.
    * `at_fraction`: Desired point (in percentage) at which the thumbnail frame should be captured. Defaults to 50% into stream.
    * `force_aspect_ratio`: If `true`, force aspect ratio; otherwise aspect is preserved when computing dimensions.
  * `audio_sample_rate`: Audio sample rate, in hertz.
  * `audio_bitrate`: Audio bitrate, in bits per second.
  * `audio_codec`: Audio codec name, eg. `mp4`.
  * `video_frame_rate`: video frame rate, in hertz.
  * `video_bitrate`: video bitrate, in bits per second.
  * `video_codec`: video codec name, eg. `mp4`.
  * `width`: desired video frame width in pixels.
  * `height`: desired video frame height in pixels.
  * `format`: File format.
  * `content_type`: Content type of resultant file. Tootsie will not be able to guess this at the moment.
  * `strip_metadata`: If true, metadata such as ID3 will be deleted. Since recent ffmpeg versions have issues with ID3 tags and character encodings, this is recommended for audio files. Requires `id3v2` tool.

Completion notification provides the following data:

* `outputs` contains an array of results. Each is a hash with the following keys:
  * `url`: the completed file.
  * `metadata`: image metadata as a hash. These are raw EXIF and IPTC data from ImageMagick.

### Image transcoding jobs

Image jobs have the `type` key set to `image`. The key `params` must be set to a hash with these keys:

* `input_url`: URL to input file, either an HTTP URL, `file:/path` URL or an S3 URL (see below).
* `versions`: Either a hash or an array of such hashes, each with the following keys:
  * `target_url`: URL to output resource, either an HTTP URL, `file:/path` URL which accepts POSTs, or an S3 URL.
  * `width`: Optional desired width of output image.
  * `height`: Optional desired height of output image.
  * `scale`: One of the following values:
    * `down` (default): The input image is scaled to fit within the dimensions `width` x `height`. If only `width` or only `height` is specified, then the other component will be computed from the aspect ratio of the input image.
    * `up`: As `fit`, but allow scaling to dimensions that are larger than the input image.
    * `fit`: Similar to `down`, but the dimensions are chosen so the output width and height are always met or exceeded. In other words, if you pass in an image that is 100x50, specifying output dimensions as 100x100, then the output image will be 150x100.
    * `none`: Don't scale at all.
  * `crop`: If true, crop the image to the output dimensions.
  * `format`: Either `jpeg`, `png` or `gif`.
  * `quality`: A quality value between 0.0 and 1.0 which will be translated to a compression level depending on the output coding. The default is 1.0.
  * `strip_metadata`: If true, metadata such as EXIF and IPTC will be deleted. For thumbnails, this often reduces the file size considerably.
  * `medium`: If `web`, the image will be optimized for web usage. See below for details.
  * `content_type`: Content type of resultant file. The system will be able to guess basic types such as `image/jpeg`.

Note that scaling always preserves the aspect ratio of the original image; in other words, if the original is 100 x 200, then passing the dimensions 100x100 will produce an image that is 50x100. Enabling cropping, however, will force the aspect ratio of the specified dimensions.

If the option `medium` specifies `web`, the following additional transformations will be performed:

* The image will be automatically rotated based on EXIF orientation metadata, since web browsers don't do this.
* CMYK images will be converted to RGB, since most web browsers don't seem to display CMYK correctly.

Completion notification provides the following data:

* `outputs` contains an array of results. Each is a hash with the following keys:
  * `url`: URL for the completed file.
* `metadata`: image metadata as a hash. These are raw EXIF and IPTC data from ImageMagick.
* `width`: width, in pixels, of original image.
* `height`: height, in pixels, of original image.
* `depth`: depth, in bits, of original image.

### Notifications

If a notification URL is provided, events will be sent to it using `POST` requests as JSON data. These are 'fire and forget' and will currently not be retried on failure, and the response status code is ignored.

There are several types of events, indicated by the `event` key:

* `started`: The job was started.
* `complete`: The job was complete. The key `time_taken` will contain the time taken for the job, in seconds. Additional data will be provided that are specific to the type of job.
* `failed`: The job failed. The key `reason` will contain a textual explanation for the failure.
* `failed_will_retry`: The job failed, but is being rescheduled for retrying. The key `reason` will contain a textual explanation for the failure.

### Resource URLs

Tootsie supports referring to inputs and outputs using URLs, namely `file:` and `http:`. Additionally, Tootsie supports its own proprietary S3 URL format.

To specify S3 URLs, we use a custom URI format:

    s3:<bucketname></path/to/file>[?<options>]

The components are:

* bucketname: The name of the S3 bucket.
* /path/to/file: The actual S3 key.
* options: Optional parameters for storage, an URL query string.

The options are:

* `acl`: One of `private` (default), `public-read`, `public-read-write` or `authenticated-read`.
* `storage_class`: Either `standard` (default) or `reduced_redundancy`.
* `content_type`: Override stored content type.

Example S3 URLs:

* `s3:myapp/video`
* `s3:myapp/thumbnails?acl=public-read&storage_class=reduced_redundancy`
* `s3:myapp/images/12345?content_type=image/jpeg`

Current limitations
-------------------

* Transcoding options are very basic.
* No client access control; anyone can submit jobs.
* SQS: Due to limitations in the `sqs` gem, only US queues may be used at the moment.
* AMQP adapter does not support measuring the queue length at the moment.
* No window support.

License
-------

This software is licensed under the MIT License.

Copyright © 2010-2013 Alexander Staubo

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
