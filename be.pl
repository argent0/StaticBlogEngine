use v5.14;
use Functional::Iterator;
use Time::Local;
use Data::Dumper;
use Template;
use HTML::Entities;
use Encode;

my %be_config = (
	metadata_end_marker => '-->',
	metadata_begin_marker => '<!---',
	post_filename_template => 'pXX.html', # replce XX for waht u want
	contents_html_filename => 'contents.html',
	post_template => 'post.tt',
	contents_template => 'content.tt',
	output_path	=> 'out',
	entities_to_encode => "áéíóúÁÉÍÓÚñÑ",
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
		$line = encode_entities(decode('utf-8',$line),
			$be_config{entities_to_encode});
		last if $line eq $be_config{metadata_end_marker};
		next if $line eq $be_config{metadata_begin_marker};
		my $expr = Parse($line);
		push @$aret, ( $$expr[0] => $$expr[1] );
	}
	close $fh;

	push @$aret, ( input_filename => $filename );

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
	my $date = shift;
	my @date = split /\//, $date;
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

		$$ret{output_filename} = $be_config{post_filename_template} =~ s/XX/$counter/r;
		$counter++;

		$previous = $ret;
		return $ret;
	});
	
}

# Build a list of posts
# sort them by date most recent first
my @posts = sort { DateToNumber($a->{Date}) cmp DateToNumber($b->{Date}) } @{Iterator::iToList( 
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

# some useful options (see below for full list)
my $config = {
    INCLUDE_PATH => 'templates',  # or list ref
    INTERPOLATE  => 1,               # expand "$var" in plain text
    POST_CHOMP   => 1,               # cleanup whitespace
    EVAL_PERL    => 1,               # evaluate Perl code blocks
	 OUTPUT_PATH	=> $be_config{output_path},
};

# create Template object
my $template = Template->new($config);

# Generate the html posts.
# And returns an array with the information to make an index.
my $titles_for_the_index = Iterator::iFold {
	# Add the content of the post
	$_[1]->{Content} = join '', @{ReadPostContent($_[1]->{input_filename})};
	say "OUT->$_[1]->{output_filename}";
	$template->process($be_config{post_template}, $_[1],$_[1]->{output_filename}) ||
		die $template->error().Dumper($_[1]);  
	push @{$_[0]}, $_[1]->{Title};
	return $_[0];
	}->([])->( Iterator::iterList $posts );

# Generates the contents page
$template->process($be_config{contents_template},
	{ Posts => $titles_for_the_index },
	$be_config{contents_html_filename} );


say Dumper($titles_for_the_index);

sub ReadPostContent {
	# Reads the content of the post. Literaly it reads all the file and returns
	# it in a single variable.
	my $filename = shift;

	open(my $fh, "<", $filename)
		or die "Can't open < $filename";

	my @lines;
	while ( my $line = <$fh> ) {
		$line =
		encode_entities(decode('utf-8',$line),$be_config{entities_to_encode});
		push @lines, $line;
	}

	return \@lines;

}
