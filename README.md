CFILTER
=======

The cfilterd.pl is a small but powerful Perl script. CFilter is a advanced Postfix Content Filter ready for production systems.

All the Info about Postfix Filtering in documented in http://www.postfix.org/FILTER_README.html and the links included in this URL. 

CFilter can be work in all Postfix filter scenarios: pre-queue, after-queue and proxy filtering.

It works through plugins: It receives the mail messages via SMTP from the postfix MTA and pass the mail to the plugins. Once processed the mails are reinjected in the Postfix queue.

The plugins are programmed in Perl and they also have available the information of the SMTP session and other arbitrary external sources, to manipulate the mail content as necessary. 

CFilter allows to configure a chain of several plugins to manipulate the mail. Plugins can be linked together to produce complex and conditional mail manipulations

An example plugin HeadersFromEnvelope is included. It permits to change some headers depending on the data of the SMTP session.

An example of configuration files is provided for Postfix and CFilter to work together.

