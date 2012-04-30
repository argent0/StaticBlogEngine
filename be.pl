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
		if ( defined($previous) ) { 
			$$previous{Next} = $ret;
			$$ret{Previous} = $previous;
		} else {	# Just for the first one
			$$ret{Previous} = undef;
		}

		$$ret{name} = $config{post_filename_template} =~ s/XX/$counter/r;
		$counter++;

		$previous = $ret;
		return $ret;
	});
	
}

# Build a list of posts
# sort them by date most recent first
my @posts = sort { DateToNumber($$a{date}) cmp DateToNumber($$b{date}) } @{Iterator::iToList( 
					Iterator::iMap { ReadPost $_[0] }->(InputIterator))};

my $posts = (Iterator::iToList Iterator::iZipWith { 
		my ($ha, $hb) = @_;
		for my $key ( keys %{$hb} ) {
			warn "Duplicated key" if (exists $$ha{$key});
			$$ha{$key} = $$hb{$key};
		}
		return $ha;
	}->( 
		sub { Iterator::is_empty($_[1]) } #stop when posts are depleted
	)->(PostsTemplatesIterator(), Iterator::iterList(\@posts)));

# Make sure the last post has undef Next (Dirty trick alert)
$$posts[-1]->{Next} = undef;

#foreach my $post ( @{$posts} ) {
#	say Dumper($post);
#}

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
#my $vars = {
#	Title => 'This is the title',
#};

# specify input filename, or file handle, text reference, etc.
my $input = 'post.tt';
#
# process input template, substituting variables
#$template->process($input, $vars)
#    || die $template->error();
#

Iterator::iFold {
	# Add the content of the post
	$_[1]->{Content} = join '', @{ReadPostContent($_[1]->{Filename})};
	$template->process($input, $_[1]) ||
		die $template->error().Dumper($_[1]);  
	return undef;
	}->(undef)->( Iterator::iterList $posts );

sub ReadPostContent {
	# Reads the content of the post. Literaly it reads all the file and returns
	# it in a single variable.
	my $filename = shift;

	open(my $fh, "<", $filename)
		or die "Can't open < $filename";

	#while(my $line = <$fh>) {
	#	chomp $line;
	#	last if $line eq $config{metadata_end_marker};
	#	next if $line eq $config{metadata_begin_marker};
	#	my $expr = Parse($line);
	#	push @$aret, ( $$expr[0] => $$expr[1] );
	#}

	my @lines;
	while ( my $line = <$fh> ) {
		push @lines, $line;
	}

	return \@lines;

}
