
package Eval::Context ;

use strict;
use warnings ;

BEGIN 
{
use vars qw ($VERSION);
$VERSION     = 0.02;
}

#-------------------------------------------------------------------------------

use English qw( -no_match_vars ) ;
use Readonly ;
Readonly my $EMPTY_STRING => q{} ;

use Carp qw(carp croak confess) ;
use File::Slurp ;
use Sub::Install qw(install_sub reinstall_sub) ;

#-------------------------------------------------------------------------------

=head1 NAME

 Eval::Context - Evalute perl code in context wrapper

=head1 SYNOPSIS

	use Eval::Context ;
	
	my $context = new Eval::Context(PRE_CODE => "use strict;\nuse warnings;\n") ;
	
	# code will be evaluated with strict and warnings loaded in the context.
	
	$context->eval(CODE => 'print "evaluated in an Eval::Context!" ;') ;
	$context->eval(CODE_FROM_FILE => 'file.pl') ;

=head1 DESCRIPTION

This module define a subroutine that let you evaluate Perl code in a specific context. The code can be passed directly as 
a string or as a file name to read from.

=head1 SUBROUTINES/METHODS

=cut

#-------------------------------------------------------------------------------

Readonly my $NEW_ARGUMENTS => 
		[
		qw(
			NAME
			PRE_CODE POST_CODE
			PERL_EVAL_CONTEXT
			PACKAGE
			INSTALL_SUBS
			DISPLAY_SOURCE_IN_CONTEXT
			INTERACTION
			FILE LINE
		)] ;

sub new
{

=head2 new(@options)

Create an Eval::Context object.  The object is used as a repository of "default" values. the values can be
temporarily overridden during the L<eval> call. All arguments have default values.

  my $context = new Eval::Context() ; # default context
  
  my $context2= new Eval::Context
		(
		NAME              => 'libraries evaluation context',
		PACKAGE           => 'libraries',
		PRE_CODE          => 'use strict ;\n"
		POST_CODE         => 'some_code_automatically_run() ;'
		PERL_EVAL_CONTEXT => undef, # libraries will always evaluated in scalar context
		
		INSTALL_SUBS =>
			{
			PrintHi => sub {print "hi\n" ;},
			TwoPlusTwo => sub {4},
			},
			
		INTERACTION =>
			{
			INFO  => \&sub_info,
			WARN  => \&sub_warn,
			DIE   => \&sub_die,
			},
			
		DISPLAY_SOURCE_IN_CONTEXT => 1, #useful when debuging
		) ;

B<Arguments>

=over 2

=item * @option - setup data for the object

=over 4

=item * NAME - use when displaying information about the object. Set automatically if not set.

=item * PACKAGE - the package the code passed to I<eval> will be in. If not set, I<main> is used.

=item * PRE_CODE - code prepended to the code passed to I<eval>

=item * POST_CODE - code appended to the code passed to I<eval>

=item * PERL_EVAL_CONTEXT - the context to eval code in (void, scalar, list). Works as  B<wantarray>

=item * INSTALL_SUBS - subs that will be available in the eval. 

A hash where the key is a function name and the value a code reference.

=item * INTERACTION

Lets you define subs used to interact with the user.

	INTERACTION      =>
		{
		INFO  => \&sub,
		WARN  => \&sub,
		DIE   => \&sub,
		}

=over 6

=item INFO

This sub will be used when displaying information.

=item WARN

This sub will be used when a warning is displayed. 

=item DIE

Used when an error occurs.

=back

The functions default to:

=over 4

=item * INFO => CORE::print

=item * WARN => Carp::carp

=item * DIE => Carp::confess

=back

=item * FILE - the file where the object has been created. Set automatically if not set. this is practical 
if you want to wrap the object.

=item * LINE - the line where the object has been created. Set automatically if not set.

=item * DISPLAY_SOURCE_IN_CONTEXT - if set, the code to evaluated will be displayed before evaluation

=back

=back

B<Return>

=over 2

=item * an B<Eval::Context> object.

=back

=cut

my ($invocant, @setup_data) = @_ ;

my $class = ref($invocant) || $invocant ;
confess 'Invalid constructor call!' unless defined $class ;

my $object = {} ;

my ($package, $file_name, $line) = caller() ;
bless $object, $class ;

$object->Setup($package, $file_name, $line, @setup_data) ;

return($object) ;
}

#-------------------------------------------------------------------------------

sub Setup
{

=head2 Setup

Helper sub called by new. This is considered private.

=cut

my ($self, $package, $file_name, $line, @setup_data) = @_ ;

my $inital_option_checking_context = { NAME => 'Anonymous', FILE => $file_name, LINE => $line,} ;
SetInteractionDefault($inital_option_checking_context) ;

CheckOptionNames
	(
	$inital_option_checking_context,
	$NEW_ARGUMENTS,
	@setup_data
	) ;

%{$self} = 
	(
	NAME => 'Anonymous',
	FILE => $file_name,
	LINE => $line,
	
	@setup_data,
	) ;

SetInteractionDefault($self) ;

return(1) ;
}

#-------------------------------------------------------------------------------

sub CheckOptionNames
{

=head2 CheckOptionNames

Verifies the named options passed to the members of this class. Calls B<{INTERACTION}{DIE}> in case
of error. This shall not be used directly.

=cut

my ($self, $valid_options, @options) = @_ ;

if (@options % 2)
	{
	$self->{INTERACTION}{DIE}->("Invalid number of argument at '$self->{FILE}:$self->{LINE}'!") ;
	}

if('HASH' eq ref $valid_options)
	{
	# OK
	}
elsif('ARRAY' eq ref $valid_options)
	{
	$valid_options = {map{$_ => 1} @{$valid_options}} ;
	}
else
	{
	$self->{INTERACTION}{DIE}->(q{Invalid 'valid_options' definition! Should be an array or hash reference.}) ;
	}

my %options = @options ;

for my $option_name (keys %options)
	{
	unless(exists $valid_options->{$option_name})
		{
		$self->{INTERACTION}{DIE}->("$self->{NAME}: Invalid Option '$option_name' at '$self->{FILE}:$self->{LINE}'!")  ;
		}
	}

if
	(
	   (defined $options{FILE} && ! defined $options{LINE})
	|| (!defined $options{FILE} && defined $options{LINE})
	)
	{
	$self->{INTERACTION}{DIE}->("$self->{NAME}: Incomplete option FILE::LINE!") ;
	}

return(1) ;
}

#-------------------------------------------------------------------------------

sub SetInteractionDefault
{
	
=head2 SetInteractionDefault

This shall not be used directly.

=cut

my ($interaction_container) = @_ ;

$interaction_container->{INTERACTION}{INFO} ||= sub {print @_} ;
$interaction_container->{INTERACTION}{WARN} ||= \&Carp::carp ;
$interaction_container->{INTERACTION}{DIE}  ||= \&Carp::confess ;

return ;
}

#-------------------------------------------------------------------------------

sub CanonizeName
{
	
=head2 CanonizeName

This shall not be used directly.

=cut

my ($name) = @_ ;
$name =~ s/[^a-zA-Z0-9_:\.]+/_/xmg ;

return($name) ;
}

#-------------------------------------------------------------------------------

Readonly my $EVAL_ARGUMENTS => [@{$NEW_ARGUMENTS}, qw(CODE CODE_FROM_FILE)] ;

sub eval ## no critic (Subroutines::ProhibitBuiltinHomonyms)
{

=head2 eval(@options)

Evaluates Perl code, passed as a string or read from a file, in the context.

Evaluation context of the code (void, scalar, list) is the same as the context this subroutine was called in
or in the context defined by B<PERL_EVAL_CONTEXT> if that option is present.

	my $context = new Eval::Context(PRE_CODE => "use strict;\nuse warnings;\n") ;
	
	$context->eval(CODE => 'print "evaluated in an Eval::Context!";') ;
	$context->eval(CODE_FROM_FILE => 'file.pl') ;

B<Arguments>

The options passed to B<eval> override the options passed to L<new>. the override is temporary during
the duration of this call.

=over 2

=item * @options - Any of the constructor options. B<one> the following options (B<mandatory>). 

=over 4

=item * CODE - a string containing perl code (valid or you'll get errors)

=item * CODE_FROM_FILE - a file containing  perl code

=back

=item * You can also override any option passed to the constructor during this call.

=back

B<Return>

=over 2

=item * What the code to be evaluated returns

=back

=cut

my ($self, @options) = @_  ;

$self->CheckOptionNames($EVAL_ARGUMENTS, @options) ;

my %options = @options ;

unless(defined $options{FILE})
	{
	my ($package, $file_name, $line) = caller() ;
	push @options, FILE => $file_name, LINE => $line
	}
	
%options = (%{$self}, @options) ;

$options{NAME} = CanonizeName($options{NAME}) ;
SetInteractionDefault(\%options) ;

my $package = GetPackageName(\%options) ;

for my $sub_name (keys %{$options{INSTALL_SUBS}})
	{
	if('CODE' ne ref $options{INSTALL_SUBS}{$sub_name} )
		{
		$options{INTERACTION}{DIE}->("$self->{NAME}: '$sub_name' from 'INSTALL_SUBS' isn't a code reference at '$options{FILE}:$options{LINE}'!")  ;
		}
		
	reinstall_sub({ code => $options{INSTALL_SUBS}{$sub_name},  into =>$package,  as   => $sub_name}) ;
	}

$options{PRE_CODE} = defined $options{PRE_CODE} ? $options{PRE_CODE} : $EMPTY_STRING ;

if(exists $options{CODE_FROM_FILE} && exists $options{CODE} )
	{
	$options{INTERACTION}{DIE}->("$self->{NAME}: Option 'CODE' and 'CODE_FROM_FILE' can't coexist at '$options{FILE}:$options{LINE}'!")  ;
	}

if(exists $options{CODE_FROM_FILE} && defined $options{CODE_FROM_FILE})
	{
	$options{CODE} = read_file($options{CODE_FROM_FILE}) ;
	$options{NAME} = CanonizeName($options{CODE_FROM_FILE}) ;
	}

unless(exists $options{CODE} && defined $options{CODE})
	{
	$options{INTERACTION}{DIE}->("$self->{NAME}: Invalid Option 'CODE' at '$options{FILE}:$options{LINE}'!")  ;
	}

$options{POST_CODE} = defined $options{POST_CODE} ? $options{POST_CODE} : $EMPTY_STRING ;

my $code_to_eval = <<"EOS" ;
#line 0 '$options{NAME}'
package $package ;
$options{PRE_CODE}

#line 1 '$options{NAME}'
$options{CODE}
$options{POST_CODE}

#end of context
EOS

if($options{DISPLAY_SOURCE_IN_CONTEXT})
	{
	$options{INTERACTION}{INFO}->("Eval::Context called at '$options{FILE}:$options{LINE}' to evaluate:\n" . $code_to_eval) ;
	}
	
$options{PERL_EVAL_CONTEXT} = wantarray unless exists $options{PERL_EVAL_CONTEXT} ;

if(defined $options{PERL_EVAL_CONTEXT})
	{
	if($options{PERL_EVAL_CONTEXT})
		{
		my @results = eval $code_to_eval ; ## no critic (BuiltinFunctions::ProhibitStringyEval)
		$options{INTERACTION}{DIE}->($EVAL_ERROR) if $EVAL_ERROR ;
		return(@results) ;
		}
	else
		{
		my $result = eval $code_to_eval ; ## no critic (BuiltinFunctions::ProhibitStringyEval)
		$options{INTERACTION}{DIE}->($EVAL_ERROR) if $EVAL_ERROR ;
		return $result ;
		}
	}
else
	{
	eval $code_to_eval ; ## no critic (BuiltinFunctions::ProhibitStringyEval)
	$options{INTERACTION}{DIE}->($EVAL_ERROR) if $EVAL_ERROR ;
	return ;
	}
}

#-------------------------------------------------------------------------------

sub GetPackageName
{

=head2 GetPackageName

This shall not be used directly.

=cut

my ($options) = @_ ;

my $package = exists $options->{PACKAGE}
		? CanonizeName($options->{PACKAGE})
		: 'main' ;

$package = $package eq $EMPTY_STRING ? 'main' : $package ;

return($package) ;
}

#-------------------------------------------------------------------------------

1 ;

=head1 BUGS AND LIMITATIONS

None so far.

=head1 AUTHOR

	Khemir Nadim ibn Hamouda
	CPAN ID: NKH
	mailto:nadim@khemir.net

=head1 LICENSE AND COPYRIGHT

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Eval::Context

You can also look for information at:

=over 4

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Eval-Context>

=item * RT: CPAN's request tracker

Please report any bugs or feature requests to  L <bug-eval-context@rt.cpan.org>.

We will be notified, and then you'll automatically be notified of progress on
your bug as we make changes.

=item * Search CPAN

L<http://search.cpan.org/dist/Eval-Context>

=back

=cut
