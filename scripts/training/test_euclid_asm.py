#!/usr/bin/env python3
"""Test euclid-asm model with sample prompts.

Usage:
    python test_euclid_asm.py --model ./euclid-asm-v1/merged_model
"""

import argparse


# Test prompts covering different task types
TEST_PROMPTS = [
    {
        "name": "Code Generation",
        "instruction": "Write a 65816 assembly routine that checks if Link has the Master Sword equipped and sets the carry flag if true.",
        "input": "The sword level is stored at $7E:0359. Master Sword = 2, Tempered = 3, Gold = 4.",
    },
    {
        "name": "Debugging",
        "instruction": "My ROM hack crashes when Link picks up a heart piece. The crash happens in this routine. What's wrong?",
        "input": """HeartPickup:
    LDA.w $7EF36B    ; Load heart pieces
    INC A            ; Increment
    PHA              ; Save to stack
    JSR UpdateHUD    ; Update display
    ; Crash happens here
    RTS""",
    },
    {
        "name": "Optimization",
        "instruction": "Optimize this routine for fewer CPU cycles. It runs every frame in the main game loop.",
        "input": """UpdatePlayerPos:
    LDA.w $7E0022    ; X position low
    CLC
    ADC.w $7E0024    ; X velocity
    STA.w $7E0022
    LDA.w $7E0023    ; X position high
    ADC.w $7E0025    ; X velocity high
    STA.w $7E0023
    RTS""",
    },
    {
        "name": "Hook Creation",
        "instruction": "Create a JSL hook at the start of the sword swing routine to add custom behavior. I have freespace at $3F:8000.",
        "input": "The sword swing routine is at $02:9A00 and starts with 'LDA.b $3C : AND.b #$80'.",
    },
    {
        "name": "Documentation",
        "instruction": "Explain what this DMA transfer routine does and document each instruction.",
        "input": """SetupVRAMTransfer:
    STZ.w $2115
    LDA.b #$80
    STA.w $2116
    STZ.w $2117
    LDA.b #$01
    STA.w $4300
    LDA.b #$18
    STA.w $4301
    REP #$20
    LDA.w #$0000
    STA.w $4302
    LDA.w #$2000
    STA.w $4305
    SEP #$20
    LDA.b #$01
    STA.w $420B
    RTS""",
    },
]


def main():
    parser = argparse.ArgumentParser(description="Test euclid-asm model")
    parser.add_argument("--model", type=str, required=True, help="Path to model directory")
    parser.add_argument("--max-tokens", type=int, default=512, help="Max tokens to generate")
    parser.add_argument("--temperature", type=float, default=0.7, help="Sampling temperature")
    args = parser.parse_args()

    print("=" * 60)
    print("EUCLID-ASM MODEL TEST")
    print("=" * 60)
    print(f"Model: {args.model}")
    print()

    # Try to load with Unsloth first, fall back to transformers
    try:
        from unsloth import FastLanguageModel
        model, tokenizer = FastLanguageModel.from_pretrained(
            args.model,
            max_seq_length=2048,
            dtype=None,
            load_in_4bit=False,
        )
        FastLanguageModel.for_inference(model)
        print("✓ Model loaded with Unsloth")
    except ImportError:
        from transformers import AutoModelForCausalLM, AutoTokenizer
        import torch

        tokenizer = AutoTokenizer.from_pretrained(args.model)
        model = AutoModelForCausalLM.from_pretrained(
            args.model,
            torch_dtype=torch.float16,
            device_map="auto",
        )
        print("✓ Model loaded with Transformers")

    # Format template
    alpaca_template = """Below is an instruction that describes a task, paired with an input that provides further context. Write a response that appropriately completes the request.

### Instruction:
{instruction}

### Input:
{input}

### Response:
"""

    alpaca_template_no_input = """Below is an instruction that describes a task. Write a response that appropriately completes the request.

### Instruction:
{instruction}

### Response:
"""

    # Run tests
    for i, test in enumerate(TEST_PROMPTS, 1):
        print()
        print("-" * 60)
        print(f"TEST {i}: {test['name']}")
        print("-" * 60)
        print(f"Instruction: {test['instruction'][:80]}...")

        if test.get('input'):
            prompt = alpaca_template.format(
                instruction=test['instruction'],
                input=test['input'],
            )
        else:
            prompt = alpaca_template_no_input.format(
                instruction=test['instruction'],
            )

        # Generate
        inputs = tokenizer(prompt, return_tensors="pt").to(model.device)

        outputs = model.generate(
            **inputs,
            max_new_tokens=args.max_tokens,
            temperature=args.temperature,
            do_sample=True,
            top_p=0.9,
            pad_token_id=tokenizer.eos_token_id,
        )

        response = tokenizer.decode(outputs[0], skip_special_tokens=True)

        # Extract just the response part
        if "### Response:" in response:
            response = response.split("### Response:")[-1].strip()

        print()
        print("Response:")
        print(response[:1000])  # Truncate long responses
        if len(response) > 1000:
            print("... (truncated)")

    print()
    print("=" * 60)
    print("TEST COMPLETE")
    print("=" * 60)


if __name__ == "__main__":
    main()
