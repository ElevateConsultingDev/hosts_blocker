#!/bin/bash

# Test the single-letter choice parsing
echo "Testing single-letter choices:"
echo

# Test different choices
test_choice() {
    local choice="$1"
    echo "Testing choice: '$choice'"
    
    # Convert single letters to full category names
    local selected_categories=""
    
    if [ -z "$choice" ] || [ "$choice" = "d" ]; then
        selected_categories=""
        echo "  -> Using default (malware and ads only)"
    elif [ "$choice" = "a" ]; then
        selected_categories="porn social gambling fakenews"
        echo "  -> Selected all categories: $selected_categories"
    else
        # Parse individual letters
        for (( i=0; i<${#choice}; i++ )); do
            local letter="${choice:$i:1}"
            case "$letter" in
                "p")
                    selected_categories="$selected_categories porn"
                    ;;
                "s")
                    selected_categories="$selected_categories social"
                    ;;
                "g")
                    selected_categories="$selected_categories gambling"
                    ;;
                "f")
                    selected_categories="$selected_categories fakenews"
                    ;;
                *)
                    echo "  -> Invalid choice: $letter"
                    return 1
                    ;;
            esac
        done
        
        # Remove leading space
        selected_categories="${selected_categories# }"
        echo "  -> Selected categories: '$selected_categories'"
    fi
    echo
}

# Test various choices
test_choice "p"
test_choice "s"
test_choice "g"
test_choice "f"
test_choice "ps"
test_choice "psg"
test_choice "psgf"
test_choice "a"
test_choice "d"
test_choice ""

echo "All tests completed successfully!"
