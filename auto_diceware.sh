#!/bin/bash

# Usage: auto_diceware.sh [options]
#
# Options:
#	-w wordList
#		Specify the list of words to draw from.
#	-m minWordLength
#		Don't use any words shorter than minWordLength. (default: 3)
#	-n number of words
#

DEFAULT_WORD_LIST="word_list_en_US"

function PrintUsage
{
cat << EOF
usage: $0 options

Randomly pick a word from the given word list. Uses /dev/random
For entropy, so should be reasonably secure, but may hang if
there is insufficient entropy in pool.

OPTIONS:
	-h		Show this message
	-w		Specify the file containing the list of words to draw from.
	-m		Don't use any words shorter than this. (default: 3)
	-n		number of words to pick.
EOF
}

# Parse parameters
function parseParams
{
	while getopts "hw:m:n:" OPTION
	do
		case $OPTION in
			h)
				PrintUsage
				exit 1
				;;
			w)
				WORD_LIST=$OPTARG
				;;
			m)
				MIN_WORD_LEN=$OPTARG
				;;
			n)
				NUM_WORDS=$OPTARG
				;;
			?)
				PrintUsage
				exit
				;;
		esac
	done
}


# Check supplied arguments, and adjust variables as neccessary.
function checkParams
{
	if [[ -z "$WORD_LIST" ]]
	then
		WORD_LIST="$DEFAULT_WORD_LIST"
	elif [[ ! -e "$WORD_LIST" ]]
	then
		echo "Error: Can't find word list!"
		exit 2
	fi
	
	if [[ -z "$MIN_WORD_LEN" ]]
	then
		# A sensible default.
		MIN_WORD_LEN="3"
	fi
	
	if [[ -z "$NUM_WORDS" ]]
	then
		NUM_WORDS="1"
	fi
}

# Get number of words in word list.
function getWordListLen
{
	# line count.  Should be 1 word per line.
	local LINE_COUNT=`cat $WORD_LIST | wc -l`
	LIST_WORD_COUNT=`cat $WORD_LIST | wc -w`

	# Check word list format.
	if [[ "$LINE_COUNT" -ne "$LIST_WORD_COUNT" ]]
	then
		echo "Error: 1 word per line in the word list please."
		exit 3
	fi
}

function setNumBytesOfEntropyNeededPerWord
{
	getWordListLen

	NUM_BYTES_PER_WORD=1

	while [[ "$LIST_WORD_COUNT" -gt $(echo "2^($NUM_BYTES_PER_WORD*8)" | bc) ]]
	do
		NUM_BYTES_PER_WORD=$(expr $NUM_BYTES_PER_WORD + 1)
	done
}

function getRandomWordIndex
{
	# Get the required amount of entropy
	local randomNum=$(od -An -N$NUM_BYTES_PER_WORD -i /dev/random)

	# We don't want zero.
	if [[ "$randomNum" -eq 0 ]]
	then
		randomNum=1
	fi

	# Adjust the number so that it is within the corrent range.
	# (That is, between 1 and "$LIST_WORD_COUNT").
	local maxRandomNumValue=$(echo "2^($NUM_BYTES_PER_WORD*8)" | bc)
	local randomWordIndex=$(echo "$randomNum/$maxRandomNumValue*$LIST_WORD_COUNT" | calc -p)

	# Round up to nearest whole number.
	randomWordIndex=$(echo "ceil($randomWordIndex)" | calc -p)

	# Return index.
	echo $randomWordIndex
}

function getRandomWord
{
	# Now to retrieve the actual word.
	local word=$(cat "$WORD_LIST" | head -$(getRandomWordIndex) | tail -1)

	# Make sure that all letters in the word are lower case.
	local word=$(echo $word | tr '[A-Z]' '[a-z]')

	echo $word
}

parseParams $@
checkParams
setNumBytesOfEntropyNeededPerWord

NUM_WORDS_TO_GO=$NUM_WORDS

while [[ $NUM_WORDS_TO_GO -ne 0 ]]
do
	WORD=$(getRandomWord)

	while [[ $(expr length "$WORD") -lt $MIN_WORD_LEN ]]
	do
		WORD=$(getRandomWord)
	done

	echo "$WORD"

	# Decrement "NUM_WORDS_TO_GO"
	NUM_WORDS_TO_GO=$(expr $NUM_WORDS_TO_GO - 1)
done

