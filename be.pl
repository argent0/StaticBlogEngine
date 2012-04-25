use v5.14;
use Functional::Iterator;
use Time::Local;
use Data::Dumper;
use Template;

my %config = (
	metadata_end_marker => '-->',
	metadata_begin_marker => '<!---',
	post_filename_template => 'pXX.html', # replce XX for waht u want
);

sub InputIterator {
	return Iterator->new ( sub {
		return Iterator::empty() unless my $line = <>;
      chomp $line;
      return $line;
	});
}

sub ReadPost {
	# Reads the post metadata and generates a hash.
	# The first parameter is the file name.

	my $filename = shift;

	open(my $fh, "<", $filename)
		or die "Can't open < $filename";

	my $aret = [];

	while(my $line = <$fh>) {
		chomp $line;
		last if $line eq $config{metadata_end_marker};
		next if $line eq $config{metadata_begin_marker};
		my $expr = Parse($line);
		push @$aret, ( $$expr[0] => $$expr[1] );
	}
	close $fh;

	push @$aret, ( Filename => $filename );

	my %ret = @$aret;

	return \%ret;

}

sub Parse {
	# Parses one string of metadata
	# Metadata strings are of the form
	# Varname: value

	my $string = shift;
	my @parts = split /:/,$string,2;
	for (@parts) {s/^\s*|\s*$//g}
	return \@parts;
}

sub DateToNumber {
	my @date = split /\//, shift;
	return join('',@date);
}

# Build a list of posts
#my @posts = Iterator::iToList( 
#					Iterator::iMap { ReadPost $_[0] }->(InputIterator));

# sort them by date most recent first
#say Dumper( sort { DateToNumber($$a{date}) cmp DateToNumber($$b{date}) }
#	@posts );

sub PostsTemplatesIterator {
	# As the first and the last post are special in the sences that they don't
	# have a previos and posterior post respectively, I create this iterator that
	# makes the last and first post special.
	# The Pourpose of this iterator is to make a list of hashes to be merged with
	# the other information about the post.

	my $previous = undef;
	my $counter = 0;

	return Iterator->new( sub {
		my $ret = {};
		if ( defined($previous) ) { # Just for the first one
			$$previous{Next} = $ret;
			$$ret{Previous} = $previous;
		} else {
			$$ret{Previous} = undef;
		}

		$$ret{name} = $config{post_filename_template} =~ s/XX/$counter/r;
		$counter++;

		$previous = $ret;
		return $ret;
	});
	
}

say Dumper( Iterator::iToList Iterator::iTake(4)->(PostsTemplatesIterator()));
exit;
# some useful options (see below for full list)
my $config = {
    INCLUDE_PATH => 'templates',  # or list ref
    INTERPOLATE  => 1,               # expand "$var" in plain text
    POST_CHOMP   => 1,               # cleanup whitespace
	 #PRE_PROCESS  => 'header',        # prefix each template
    EVAL_PERL    => 1,               # evaluate Perl code blocks
};

# create Template object
my $template = Template->new($config);

# define template variables for replacement
my $vars = {
	Title => 'This is the title',
};

# specify input filename, or file handle, text reference, etc.
my $input = 'post.tt';

# process input template, substituting variables
$template->process($input, $vars)
    || die $template->error();

