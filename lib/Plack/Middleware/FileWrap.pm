package Plack::Middleware::FileWrap;

# ABSTRACT: Wrap file with headers/footers in Plack

use strict;
use warnings;
use parent qw( Plack::Middleware );

use Plack::Util;
use Plack::Util::Accessor qw( headers footers );

sub call {
    my($self, $env) = @_;
    
    my $headers = _wrap_files($self->headers);
    my $footers = _wrap_files($self->footers);
    return $self->app->($env) unless defined($headers) or defined($footers);
    
    $self->response_cb($self->app->($env), sub {
        my $res = shift;

        if (defined $res->[2]) { # do we need it?
            my $body;
            Plack::Util::foreach($res->[2], sub { $body .= $_[0] });
            my $new_body = $headers . $body . $footers;
            $res->[2] = [ $new_body ];
            my $h = Plack::Util::headers($res->[1]);
            $h->set('Content-Length', length $new_body);
        }
    });
}

sub _wrap_files {
    my ($files) = @_;
    
    return unless defined $files;
    return $$files if ref $files eq 'SCALAR'; # \''
    unless (ref $files) { # '/path/to/file'
        $files = [$files];
    }
    
    my $body;
    foreach my $file (@$files) {
        if (ref $file eq 'SCALAR') {
            $body .= $$file;
        } else {
            if (open(my $fh, '<', $file)) {
                local $/;
                $body .= <$fh>;
                close($fh);
            } else {
                warn "[FileWrap] Can't open $file: $!\n";
            }
        }
    }
    
    return $body;
}

1;

=head2 SYNOPSIS

    use Plack::Builder;

    # with text
    mount '/static/docs/' => builder {
        enable 'FileWrap', headers => [\'TEST HEAD'], footers => [\'TEST FOOT'];
        Plack::App::File->new( root => "/path/to/static/docs" )->to_app;
    },
    
    # with file
    builder {
        enable 'FileWrap', headers => ['/path/to/headerA.html', '/path/to/headerB.html'], footers => ['/path/to/footer.html'];
        $app;
    },
    
=head2 DESCRIPTION

Enable this middleware to allow your Plack-based application to have common header/footer.

=head3 CONFIGURATIONS

=over 4

=item headers, footers

Arrayref. Text ref or file paths. can be mixed like

    headers => [ \'<!-- blabla -->', '/path/to/file/header.html' ]

=back