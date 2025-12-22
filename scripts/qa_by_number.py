#!/usr/bin/env python3
"""Answer questions by number instead of full ID (mobile-friendly)."""

import asyncio
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent.parent / "hafs" / "src"))


async def main():
    if len(sys.argv) < 2:
        print("Usage: python qa_by_number.py <number>")
        print("\nAvailable questions:")

        from agents.training.background import QuestionCurator
        curator = QuestionCurator()
        batch = curator.get_today_batch()

        if not batch:
            print("No questions available")
            return

        for i, q in enumerate(batch.questions, 1):
            print(f"\n{i}. {q.question_text[:80]}...")
            print(f"   ID: {q.question_id}")

        return

    # Get question number
    try:
        number = int(sys.argv[1])
    except ValueError:
        print(f"Error: '{sys.argv[1]}' is not a number")
        return

    # Get today's batch
    from agents.training.background import QuestionCurator
    curator = QuestionCurator()
    batch = curator.get_today_batch()

    if not batch or number < 1 or number > len(batch.questions):
        print(f"Error: Question {number} not found (batch has {len(batch.questions) if batch else 0} questions)")
        return

    question = batch.questions[number - 1]
    question_id = question.question_id

    print(f"\n=== Question {number} ===")
    print(question.question_text)
    print()

    # Run assisted workflow
    from agents.training.background.assisted_qa import assisted_answer_workflow
    from agents.training.background import QuestionCurator, QAConverter

    print("Generating draft answer...")
    result = await assisted_answer_workflow(question_id)

    print("\n" + "=" * 60)
    print("DRAFT ANSWER")
    print("=" * 60)
    print(result['draft_answer'])
    print()
    print(f"Sources: {', '.join(result['sources'])}")
    print(f"Confidence: {result['confidence']}")
    print()

    # Ask for choice
    print("Options:")
    print("  [a] Accept and save (generates 3-5 training samples)")
    print("  [e] Edit before saving")
    print("  [s] Skip")
    print()

    choice = input("Choice [a/e/s]: ").lower().strip()

    if choice == 'a':
        curator = QuestionCurator()
        answered = curator.answer_question(question_id, result['draft_answer'])
        print(f"✓ Answer saved ({answered.answer_word_count} words)")

        print("\nConverting to training samples...")
        converter = QAConverter()
        await converter.setup()
        samples = await converter.convert_qa_to_samples(answered, num_variations=3)

        if samples:
            output_dir = Path.home() / ".context" / "training" / "qa_samples"
            output_path = output_dir / f"{question_id}.jsonl"
            await converter.save_samples(samples, output_path)

            print(f"✓ Generated {len(samples)} training samples")
            print(f"Saved to: {output_path}")

    elif choice == 's':
        curator = QuestionCurator()
        curator.skip_question(question_id)
        print("✓ Question skipped")
    else:
        print("Cancelled")


if __name__ == "__main__":
    asyncio.run(main())
