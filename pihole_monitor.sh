#!/usr/bin/env bash
#
# Pi-Hole Activity Monitor
# Written by Atanas Malinov 1/1/2022
#
# 27/07/2023 rewritten with compromise between load efficiency and readability
# 04/08/2023 added trap to cleanup on exit, orange is discarded
# 11/08/2023 delay function is added as faster alternative of sleep
# 24/09/2023 added main() function and running in background

# Isolating the script to run in the background
{
  # Enable bash strict mode for better error handling and reliability
  set -o errexit  # Exit immediately if a command fails
  set -o errtrace # Enable errtrace option to catch errors in functions and subshells
  set -o nounset  # Treat unset variables as errors
  set -o pipefail # Return the exit status of the last command in a pipeline

  # Enable xtrace for debugging and tracing commands
  #set -o xtrace       # Print each command before it is executed

  # Set the Internal Field Separator (IFS) to newline and tab characters
  IFS=$'\n\t'

  # Function to cleanup and provide descriptive error messages
  # shellcheck disable=SC2317  # Don't warn about unreachable commands in this function
  cleanup() {
    local error_message="${1:-An unspecified error occurred.}"
    local exit_status="${2:-1}"
    for pin in "${RED_LED_PIN}" "${GREEN_LED_PIN}"; do
      printf 0 >"/sys/class/gpio/gpio${pin}/value"
      printf '%d' "${pin}" >'/sys/class/gpio/unexport'
    done
    printf '[ERROR %d]: %s\n' "${exit_status}" "${error_message}" >&2
    exit "${exit_status}"
  }

  # Trap to cleanup on exit
  trap 'cleanup "Script was interrupted or encountered an error."' EXIT

  # Configuration constants
  readonly RED_LED_PIN=27
  readonly GREEN_LED_PIN=22
  readonly ON_TIME=0.1
  readonly OFF_TIME=0.01
  readonly PAUSE_TIME=1
  readonly PIHOLE_LOG='/var/log/pihole.log'

  # Assigns file descriptor to the delay_fd variable to subtitute with an empty string
  exec {delay_fd}<> <(:)

  # Function to introduce a delay (alternative to 'sleep' command)
  delay() {
    read -rt "$1" -u "${delay_fd}" || :
  }

  # Function to blink LED
  blink_led() {
    local led_pin="$1"
    printf 1 >"/sys/class/gpio/gpio${led_pin}/value"
    delay "${ON_TIME}"
    printf 0 >"/sys/class/gpio/gpio${led_pin}/value"
    delay "${OFF_TIME}"
  }

  # Function to export pins and set direction as output
  setup_pins() {
    for pin in "${RED_LED_PIN}" "${GREEN_LED_PIN}"; do
      printf '%d' "${pin}" >"/sys/class/gpio/export"
      printf 'out' >"/sys/class/gpio/gpio${pin}/direction"
    done
  }

  # Function to determine the LED color and blink the LEDs accordingly
  resolve_color() {
    case "${input}" in
    *" blacklisted "* | *" blocked "*)
      blink_led "${RED_LED_PIN}"
      ;;
    *" reply "* | *" cached "* | *" query"* | *" forwarded "*)
      blink_led "${GREEN_LED_PIN}"
      ;;
    esac
  }

  # Main function
  main() {
    # Export pins and set direction as output
    setup_pins

    # Test LED colors
    blink_led "${RED_LED_PIN}"
    delay "${PAUSE_TIME}"
    blink_led "${GREEN_LED_PIN}"
    delay "${PAUSE_TIME}"

    # Monitor pi-hole activity through pihole.log
    while read -r input; do
      resolve_color
    done < <(tail --follow=name --lines=1 "${PIHOLE_LOG}")
  }

  # Run the main function
  main
} &
