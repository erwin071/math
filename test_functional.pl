#!/usr/bin/env perl
use strict;
use warnings;
use JSON::PP qw(decode_json encode_json);
use utf8;
binmode STDOUT, ':encoding(UTF-8)';
binmode STDERR, ':encoding(UTF-8)';

sub ok { my ($cond,$name)=@_; print(($cond ? "ok" : "not ok") . " - $name\n"); die "FAILED: $name\n" unless $cond; }
sub normalize { my ($v)=@_; $v = '' unless defined $v; $v = lc($v); $v =~ s/^\s+|\s+$//g; $v =~ s/\s+/ /g; $v =~ s/×/x/g; return $v; }
sub shuffle { return @_; }

my $MAX_ATTEMPTS = 2;
my $REVIEW_CORRECT_TO_REMOVE = 1;
my $ADAPTIVE_WINDOW = 3;
my $SESSION_SIZE = 10;
my $MIN_LEVEL = 1;
my $MAX_LEVEL = 5;
my (%state, %ui);

my $json = do { local $/; open my $fh, '<:raw', 'questions.json' or die $!; <$fh> };
my $questions = decode_json($json);
ok(ref($questions) eq 'ARRAY' && @$questions > 0, 'questions.json loads and is non-empty');

my $html = do { local $/; open my $fh, '<:encoding(UTF-8)', 'index.html' or die $!; <$fh> };
for my $id (qw(topicFilter difficultyFilter mode restartBtn exportBtn importBtn clearStorageBtn importFile backupStatus progress score attempted percent numberBadge topicBadge difficultyBadge prompt questionImage choices shortAnswer answerInput checkBtn questionCard feedback hint solution solutionBox prevBtn nextBtn resultCard summaryText reviewList emailBtn emailStatus studentName)) {
  ok($html =~ /id="$id"/, "html contains #$id");
}
for my $fn (qw(normalize shuffle getQuestionState buildBackupPayload saveState loadSavedState downloadJson importBackup clearSavedProgress resetCurrentProgress loadExternalQuestions loadTopics adaptiveLevel buildAdaptivePool takeSession buildPool render isCorrect checkAnswer showFeedback currentStats updateStats buildSummaryText sendSummary finish)) {
  ok($html =~ /function\s+$fn\s*\(/, "html defines $fn()");
}

sub build_backup_payload {
  return {
    app => 'grade4-math-practice', appVersion => 2, exportedAt => 'now',
    ui => { topic=>$ui{topic}, difficulty=>$ui{difficulty}, mode=>$ui{mode}, index=>$state{index}, sessionCursor=>$state{sessionCursor} },
    questions => [ map { +{ id=>$_->{id}, version=>$_->{version}, topic=>$_->{topic}, difficulty=>$_->{difficulty}, prompt=>$_->{prompt} } } @$questions ],
    questionState => $state{questionState}, history => $state{history}, adaptiveLevel => $state{adaptiveLevel}
  };
}
sub current_stats {
  my @states = grep { defined } map { $state{questionState}{$_->{id}} } @{$state{pool}};
  my $attempted = grep { ($_->{status}//'') ne '' && ($_->{status}//'') ne 'not-attempted' } @states;
  my $correct = grep { $_->{correct} } @states;
  return ($attempted, $correct);
}
sub build_summary_text {
  my ($student) = @_;
  my ($attempted, $correct) = current_stats();
  my @lines;
  push @lines, 'Grade 4 Math Practice — now';
  push @lines, '=' x 46;
  push @lines, 'Student: ' . (($student && $student =~ /\S/) ? $student : 'Student');
  push @lines, 'Correct: ' . $correct . ' / ' . $attempted . ' attempted';
  push @lines, 'Total recorded answers: ' . scalar(@{$state{history}});
  for my $i (0..$#{$state{pool}}) { push @lines, ($i+1) . '. ' . $state{pool}[$i]{topic} . ' (' . $state{pool}[$i]{id} . ')'; }
  return join("\n", @lines);
}


my %ids;
for my $q (@$questions) {
  ok(defined $q->{id} && $q->{id} ne '', "question has id");
  ok(!$ids{$q->{id}}++, "unique id $q->{id}");
  ok(defined $q->{version}, "version exists $q->{id}");
  ok(defined $q->{topic} && $q->{topic} ne '', "topic exists $q->{id}");
  ok($q->{difficulty} >= 1 && $q->{difficulty} <= 5, "difficulty range $q->{id}");
  ok($q->{type} eq 'text' || $q->{type} eq 'choice', "type valid $q->{id}");
  ok(defined $q->{prompt} && $q->{prompt} ne '', "prompt exists $q->{id}");
  ok(ref($q->{answers}) eq 'ARRAY' && @{$q->{answers}} >= 1, "answers exist $q->{id}");
  ok(defined $q->{hint}, "hint exists $q->{id}");
  ok(defined $q->{solution}, "solution exists $q->{id}");
  if ($q->{type} eq 'choice') {
    ok(ref($q->{choices}) eq 'ARRAY' && @{$q->{choices}} >= 2, "choices exist $q->{id}");
    my %choice = map { normalize($_) => 1 } @{$q->{choices}};
    ok(grep({ $choice{normalize($_)} } @{$q->{answers}}), "choice answer appears in choices $q->{id}");
  }
  if ($q->{image}) { ok(-f $q->{image}, "image exists $q->{id} $q->{image}"); }
}

%state = (pool => [], index => 0, questionState => {}, history => [], sessionCursor => 0, adaptiveLevel => 2, pendingReviewRemoval => undef);
%ui = (topic => 'all', difficulty => 'all', mode => 'ordered');

sub get_qs {
  my ($q) = @_;
  $state{questionState}{$q->{id}} ||= { id=>$q->{id}, version=>$q->{version}, status=>'not-attempted', attempts=>0, correct=>JSON::PP::false, reviewCorrectStreak=>0, lastAnswer=>'', updatedAt=>undef };
  return $state{questionState}{$q->{id}};
}
sub adaptive_level {
  my @recent = @{$state{history}} > $ADAPTIVE_WINDOW ? @{$state{history}}[-$ADAPTIVE_WINDOW..-1] : @{$state{history}};
  if (@recent >= $ADAPTIVE_WINDOW) {
    my $correct = grep { $_->{ok} } @recent;
    if ($correct == @recent) { $state{adaptiveLevel} = $state{adaptiveLevel} + 1 > $MAX_LEVEL ? $MAX_LEVEL : $state{adaptiveLevel} + 1; }
    elsif ($correct <= 1) { $state{adaptiveLevel} = $state{adaptiveLevel} - 1 < $MIN_LEVEL ? $MIN_LEVEL : $state{adaptiveLevel} - 1; }
  }
  return $state{adaptiveLevel};
}
sub build_adaptive_pool {
  my (@pool) = @_;
  my $target = adaptive_level();
  my @c = grep { my $s=$state{questionState}{$_->{id}}; $_->{difficulty} == $target && (!defined($s) || ($s->{status}//'') ne 'correct') && (($s->{attempts}//0) < $MAX_ATTEMPTS) } @pool;
  @c = grep { $_->{difficulty} == $target && (($state{questionState}{$_->{id}}{attempts}//0) < $MAX_ATTEMPTS) } @pool unless @c;
  @c = grep { (($state{questionState}{$_->{id}}{attempts}//0) < $MAX_ATTEMPTS) } @pool unless @c;
  @c = @pool unless @c;
  return @c;
}
sub take_session {
  my ($ordered, @pool) = @_;
  return @pool if @pool <= $SESSION_SIZE;
  return @pool[0..$SESSION_SIZE-1] unless $ordered;
  my $start = ($state{sessionCursor} * $SESSION_SIZE) % @pool;
  my @chunk; push @chunk, $pool[($start + $_) % @pool] for 0..$SESSION_SIZE-1;
  return @chunk;
}
sub build_pool {
  my (%opt) = @_;
  my $keep = $opt{keepIndex} // 0;
  my @pool = grep { ($ui{topic} eq 'all' || $_->{topic} eq $ui{topic}) && ($ui{mode} eq 'adaptive' || $ui{difficulty} eq 'all' || $_->{difficulty} eq 0+$ui{difficulty}) } @$questions;
  @pool = grep { ($state{questionState}{$_->{id}}{status}//'') eq 'review' } @pool if $ui{mode} eq 'review';
  @pool = build_adaptive_pool(@pool) if $ui{mode} eq 'adaptive';
  @pool = shuffle(@pool) if $ui{mode} eq 'random';
  my @sess = take_session($ui{mode} eq 'ordered', @pool);
  $state{pool} = \@sess;
  $state{index} = $keep ? ($state{index} < (@sess ? @sess-1 : 0) ? $state{index} : (@sess ? @sess-1 : 0)) : 0;
}
sub is_correct { my ($q,$ans)=@_; my $n=normalize($ans); return scalar grep { normalize($_) eq $n } @{$q->{answers}}; }
sub check_answer {
  my ($ans) = @_;
  my $q = $state{pool}[$state{index}] or return 0;
  my $qs = get_qs($q);
  return 0 if $qs->{attempts} >= $MAX_ATTEMPTS;
  return 0 if !defined($ans) || $ans =~ /^\s*$/;
  my $ok = is_correct($q,$ans) ? 1 : 0;
  $qs->{attempts}++;
  $qs->{correct} = $ok;
  $qs->{reviewCorrectStreak} = $ok ? (($qs->{reviewCorrectStreak}//0)+1) : 0;
  $qs->{status} = ($ok && $qs->{reviewCorrectStreak} >= $REVIEW_CORRECT_TO_REMOVE) ? 'correct' : 'review';
  $qs->{lastAnswer} = $ans; $qs->{version} = $q->{version}; $qs->{updatedAt} = 'now';
  $state{pendingReviewRemoval} = $q->{id} if $ok && $ui{mode} eq 'review';
  push @{$state{history}}, { id=>$q->{id}, version=>$q->{version}, answer=>$ans, ok=>$ok, at=>'now', topic=>$q->{topic}, prompt=>$q->{prompt} };
  adaptive_level() if $ui{mode} eq 'adaptive';
  return 1;
}
sub next_click {
  if ($state{pendingReviewRemoval} && $ui{mode} eq 'review') { $state{pendingReviewRemoval}=undef; build_pool(keepIndex=>1); return 'review-rebuild'; }
  if ($ui{mode} eq 'adaptive') { $state{index} = $state{index}+1 < @{$state{pool}} ? $state{index}+1 : scalar @{$state{pool}}; return $state{index} >= @{$state{pool}} ? 'finish' : 'next'; }
  if ($state{index} < @{$state{pool}}-1) { $state{index}++; return 'next'; }
  return 'finish';
}

for my $mode (qw(ordered random adaptive)) {
  %state = (pool => [], index => 0, questionState => {}, history => [], sessionCursor => 0, adaptiveLevel => 2, pendingReviewRemoval => undef);
  %ui = (topic => 'all', difficulty => 'all', mode => $mode);
  build_pool();
  ok(@{$state{pool}} > 0 && @{$state{pool}} <= $SESSION_SIZE, "$mode builds session pool");
  my $first = $state{pool}[0]{id};
  my $ans = $state{pool}[0]{answers}[0];
  ok(check_answer($ans), "$mode check accepts correct answer");
  my $move = next_click();
  ok($move eq 'next' || $move eq 'finish', "$mode next after check works");
  ok($move eq 'finish' || $state{pool}[$state{index}]{id} ne $first || @{$state{pool}} == 1, "$mode moves off first question when possible");
}

# lock flow
%state = (pool => [], index => 0, questionState => {}, history => [], sessionCursor => 0, adaptiveLevel => 2, pendingReviewRemoval => undef);
%ui = (topic => 'all', difficulty => 'all', mode => 'adaptive'); build_pool();
my $qid = $state{pool}[0]{id};
ok(check_answer('__wrong1__'), 'adaptive first wrong answer recorded');
ok(check_answer('__wrong2__'), 'adaptive second wrong answer records lock');
ok($state{questionState}{$qid}{attempts} == $MAX_ATTEMPTS, 'question locked at max attempts');
my $lock_move = next_click();
ok(($lock_move eq 'next' || $lock_move eq 'finish'), 'adaptive next after lock returns navigation result');

# review flow
%state = (pool => [], index => 0, questionState => {}, history => [], sessionCursor => 0, adaptiveLevel => 2, pendingReviewRemoval => undef);
%ui = (topic => 'all', difficulty => 'all', mode => 'ordered'); build_pool();
check_answer('__wrong__');
%ui = (topic => 'all', difficulty => 'all', mode => 'review'); build_pool();
ok(@{$state{pool}} >= 1, 'review mode includes wrong answer');
check_answer($state{pool}[0]{answers}[0]);
ok(defined $state{pendingReviewRemoval}, 'review correct sets pending removal');
next_click();
ok(!defined $state{pendingReviewRemoval}, 'review next clears pending removal');

# backup/summary/export/import-like payload flow
%state = (pool => [], index => 0, questionState => {}, history => [], sessionCursor => 0, adaptiveLevel => 2, pendingReviewRemoval => undef);
%ui = (topic => 'all', difficulty => 'all', mode => 'ordered'); build_pool();
check_answer($state{pool}[0]{answers}[0]);
my $payload = build_backup_payload();
ok($payload->{app} eq 'grade4-math-practice', 'export payload has app id');
ok(@{$payload->{questions}} == @$questions, 'export payload contains question metadata');
ok(scalar(keys %{$payload->{questionState}}) >= 1, 'export payload contains progress');
my $encoded = encode_json($payload);
my $imported = decode_json($encoded);
ok($imported->{questionState}{$state{pool}[0]{id}}{status} eq 'correct', 'import payload preserves answer state');
my $summary = build_summary_text('Test Student');
ok($summary =~ /Test Student/ && $summary =~ /Correct:/ && $summary =~ /Total recorded answers:/, 'summary text includes student and stats');

print "All simulated functional tests passed. Questions tested: ".scalar(@$questions)."\n";
