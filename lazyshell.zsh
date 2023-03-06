#!/usr/bin/env zsh

# -*- tab-width: 2; encoding: utf-8 -*-

## src: [github/ not-poma/ lazyshell](https://github.com/not-poma/lazyshell)

LAZYSHELL_VERSION="0.0.3"

__lzsh_get_distribution_name() {
	if [[ "$(uname)" == "Darwin" ]]; then
		echo "$(sw_vers -productName) $(sw_vers -productVersion)" 2>/dev/null
	else
		echo "$(\cat /etc/*-release 2>/dev/null | grep PRETTY_NAME | cut -d'"' -f2)"
	fi
}

__lzsh_get_os_prompt_injection() {
	local os=$(__lzsh_get_distribution_name)
	if [[ -n "$os" ]]; then
		echo " for $os"
	else
		echo ""
	fi
}

__lzsh_preflight_check() {
if [ $(grep OPENAI_API_KEY "$HOME/.config/lazyshell/config" | awk -F"=" '{ print $2 }') ]; then
		export OPENAI_API_KEY=$(grep OPENAI_API_KEY $HOME/.config/lazyshell/config | awk -F"=" '{ print $2 }')

	elif [ ! -z "$OPENAI_API_KEY" ]; then
		## nothing to do OPEN_API_KEY exists
		
	else
		echo ""
		echo "[lazyshell] Error: OPENAI_API_KEY is not set"
		echo "[lazyshell] Get your API key from https://beta.openai.com/account/api-keys and then run:"
		echo "[lazyshell] export OPENAI_API_KEY=<your API key>"
		zle reset-prompt
		return 1		
	fi
}

__lzsh_llm_api_call() {
	## calls the llm API, shows a nice spinner while it's running 
	## called without a subshell to stay in the widget context, returns the answer in $generated_text variable
	local intro="$1"
	local prompt="$2"
	local progress_text="$3"
	
	local response_file=$(gmktemp --suffix=".json" --tmpdir=$HOME/tmp/lazyshell)
	#echo -n "[lazyshell/ __lzsh_llm_api_call] response: $response_file"

	local escaped_prompt=$(echo "$prompt" | jq -R -s '.')
	local escaped_intro=$(echo "$intro" | jq -R -s '.')
	local data='{"messages":[{"role": "system", "content": '"$escaped_intro"'},{"role": "user", "content": '"$escaped_prompt"'}],"model":"gpt-3.5-turbo","max_tokens":256,"temperature":0}'
	#echo -n "[lazyshell/ __lzsh_llm_api_call] data: $data"
	
	## Read the response from file
	## Todo: avoid using temp files
	set +m
	{ curl -s -X POST -H "Content-Type: application/json" -H "Authorization: Bearer $OPENAI_API_KEY" -d "$data" https://api.openai.com/v1/chat/completions > "$response_file" } &>/dev/null &
	local pid=$!
	
	## Display a spinner while the API request is running in the background
	local spinner=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
	while true; do
		for i in "${spinner[@]}"; do
			if ! kill -0 $pid 2> /dev/null; then
				break 2
			fi
			
			zle -R "$i $progress_text"
			sleep 0.1
		done
	done
	
	wait $pid
	if [ $? -ne 0 ]; then
		zle -M "[lazyshell] Error: API request failed"
		return 1
	fi
	
	local response=$(\cat "$response_file")
	#\rm "$response_file"
	
	local error=$(echo -E $response | jq -r '.error.message')
	generated_text=$(echo -E $response | jq -r '.choices[0].message.content' | tr '\n' '\r' | sed -e $'s/^[ \r`]*//; s/[ \r`]*$//' | tr '\r' '\n')
	#echo -n "[lazyshell/ __lzsh_llm_api_call] generated_text: $generated_text"
	
	if [ $? -ne 0 ]; then
		zle -M "[lazyshell] Error: Invalid API response format"
		return 1
	fi
	
	if [[ -n "$error" && "$error" != "null" ]]; then
		zle -M "[lazyshell] API error: $error"
		return 1
	fi
}

## Read user query and generates a zsh command
__lazyshell_complete() {
	$(__lzsh_preflight_check) || return 1
	
	local buffer_context="$BUFFER"
	local cursor_position=$CURSOR
	
	## Read user input
	## Todo: use zle to read input
	local REPLY
	autoload -Uz read-from-minibuffer
	read-from-minibuffer '[lazyshell] >Query: '
	BUFFER="$buffer_context"
	CURSOR=$cursor_position
	
	
	local os=$(__lzsh_get_os_prompt_injection)
	local intro="You are a zsh autocomplete script. All your answers are a single command$os, and nothing else. You do not write any human-readable explanations. If you fail to answer, start your response with \`#\`."
	if [[ -z "$buffer_context" ]]; then
		local prompt="$REPLY"
	else
		local prompt="[lazyshell] Alter zsh command \`$buffer_context\` to comply with query \`$REPLY\`"
	fi
	
	__lzsh_llm_api_call "$intro" "$prompt" "Query: $REPLY"
	if [ $? -ne 0 ]; then
		return 1
	fi
	
	## if response starts with '#' it means GPT failed to generate the command
	if [[ "$generated_text" == \#* ]]; then
		zle -M "$generated_text"
		return 1
	fi
	
	## Replace the current buffer with the generated text
	BUFFER="$generated_text"
	CURSOR=$#BUFFER
}

## Explains the current zsh command
__lazyshell_explain() {
	$(__lzsh_preflight_check) || return 1
	
	local buffer_context="$BUFFER"
	
	local os=$(__lzsh_get_os_prompt_injection)
	local intro="You are a zsh command explanation assistant$os. You write short and concise explanations what a given zsh command does, including the arguments. You answer with no line breaks."
	local prompt="$buffer_context"
	
	__lzsh_llm_api_call "$intro" "$prompt" "[lazyshell] Fetching Explanation..."
	if [ $? -ne 0 ]; then
		return 1
	fi
	
	zle -R "# $generated_text"
	read -k 1
}


if [ $(grep OPENAI_API_KEY "$HOME/.config/lazyshell/config" | awk -F"=" '{ print $2 }') ]; then
	export OPENAI_API_KEY=$(\grep OPENAI_API_KEY $HOME/.config/lazyshell/config | awk -F"=" '{ print $2 }')
	
elif [ ! -z "$OPENAI_API_KEY" ]; then
	## nothing to do OPEN_API_KEY exists
else
	echo ""
	echo "[lazyshell] Error: OPENAI_API_KEY is not set"
	echo "[lazyshell] Get your API key from https://beta.openai.com/account/api-keys and then run:"
	echo "[lazyshell] export OPENAI_API_KEY=<your API key>"
	zle reset-prompt
	return 1		
fi

## Bind the __lazyshell_complete function to the Alt-g hotkey
## Bind the __lazyshell_explain function to the Alt-e hotkey
zle -N __lazyshell_complete
zle -N __lazyshell_explain
bindkey '\eg' __lazyshell_complete
bindkey '\ee' __lazyshell_explain

typeset -ga ZSH_AUTOSUGGEST_CLEAR_WIDGETS
ZSH_AUTOSUGGEST_CLEAR_WIDGETS+=( __lazyshell_explain )

# vim:ft=zsh
