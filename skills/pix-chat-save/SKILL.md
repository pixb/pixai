---
name: pix-chat-save
description: Automatically save chat conversations to individual markdown files with unique filenames containing timestamps. Each conversation is saved to /Users/pix/dev/code/ai/pixai/chat-history directory. Use when user wants to preserve chat history, save conversation logs, or maintain a record of discussions.
---

# Chat Save Skill

This skill enables skills-compatible agents to automatically save chat conversations to individual markdown files with unique timestamps.

## Overview

- Each conversation is saved as a separate markdown file
- Filenames include timestamp to ensure uniqueness
- Files are saved to `/Users/pix/dev/code/ai/pixai/chat-history`
- Format preserves conversation structure with user/assistant markers

## Filename Format

```
chat-YYYY-MM-DD-HH-mm-ss.md
```

Example: `chat-2024-01-15-14-30-45.md`

## File Structure

```markdown
---
title: Chat Session
date: 2024-01-15T14:30:45
save_directory: /Users/pix/dev/code/ai/pixai/chat-history
---

# Chat Session - 2024-01-15 14:30:45

## User

Hello, I need help with my project.

## Assistant

I'd be happy to help! What specific assistance do you need with your project?

## User

Can you explain how to set up a new repository?

## Assistant

Certainly! Here's how you can set up a new Git repository...
```

## Usage

### Saving Conversations

Each conversation turn should be wrapped with appropriate markers:

```markdown
## User

[User's message content here]

## Assistant

[Assistant's response content here]
```

### Full Session Saving

For complete conversation logs, structure the file with all exchanges:

```markdown
---
title: Chat Session - [Session Start Time]
date: [ISO 8601 timestamp]
save_directory: /Users/pix/dev/code/ai/pixai/chat-history
---

# Chat Session - [Session Start Time]

## User

[Message 1]

## Assistant

[Response 1]

## User

[Message 2]

## Assistant

[Response 2]

[...continue for all exchanges]
```

## Frontmatter Properties

| Property | Type | Description |
|----------|------|-------------|
| `title` | string | Session title (usually "Chat Session") |
| `date` | string | ISO 8601 timestamp of session start |
| `save_directory` | string | Directory where files are saved |

## Directory Structure

```
/Users/pix/dev/code/ai/pixai/chat-history/
├── chat-2024-01-15-14-30-45.md
├── chat-2024-01-15-15-20-30.md
├── chat-2024-01-16-09-15-00.md
└── ...
```

## Complete Example

```markdown
---
title: Chat Session
date: 2024-01-15T14:30:45+08:00
save_directory: /Users/pix/dev/code/ai/pixai/chat-history
---

# Chat Session - 2024-01-15 14:30:45

## User

Hi, I need help understanding machine learning basics.

## Assistant

I'd be happy to help! Machine learning is a subset of artificial intelligence that focuses on building systems that learn from data. Here are the key concepts...

## User

What are the main types of machine learning?

## Assistant

The three main types of machine learning are:

1. **Supervised Learning** - Training with labeled data
2. **Unsupervised Learning** - Finding patterns in unlabeled data
3. **Reinforcement Learning** - Learning through trial and error with rewards

## User

Can you give me an example of supervised learning?

## Assistant

Sure! A classic example is email spam classification:
- Training data: emails labeled as "spam" or "not spam"
- The algorithm learns patterns that distinguish spam from legitimate emails
- New emails are classified based on these learned patterns

## User

Thank you, that makes sense!

## Assistant

You're welcome! Feel free to ask if you have more questions about machine learning or any other topic.
```

## Implementation Notes

1. Generate unique filename using current timestamp
2. Create directory if it doesn't exist
3. Use ISO 8601 format for timestamps in frontmatter
4. Include frontmatter at the beginning of each file
5. Use `## User` and `## Assistant` markers for clear distinction
6. Preserve original message content without modification
7. Add blank line after each section marker for proper Markdown rendering

## Error Handling

- Check if save directory exists, create if missing
- Handle file naming conflicts with millisecond precision if needed
- Validate file write permissions before saving
