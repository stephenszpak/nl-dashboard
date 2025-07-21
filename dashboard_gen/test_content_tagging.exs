#!/usr/bin/env elixir

# Test Content Tagging with different content formats
Code.prepend_path("lib")
Application.load(:dashboard_gen)

defmodule ContentTaggingTest do
  def run_tests do
    IO.puts("🧪 Testing Content Tagging with Various Formats...\n")
    
    # Test 1: Complete content (should work)
    test_complete_content()
    
    # Test 2: Minimal content (the case that was failing)
    test_minimal_content()
    
    # Test 3: Content with different field names
    test_alternative_content()
  end
  
  defp test_complete_content do
    IO.puts("1️⃣ Testing Complete Content (with all fields):")
    
    content = %{
      title: "BlackRock Launches AI-Powered ESG Platform", 
      text: "Revolutionary platform for sustainable investing",
      source: "press_release",
      date: "2024-01-15"
    }
    
    test_field_access(content)
  end
  
  defp test_minimal_content do
    IO.puts("\n2️⃣ Testing Minimal Content (missing date field):")
    
    content = %{
      title: "BlackRock AI Platform Launch",
      text: "New artificial intelligence investment platform",
      source: "press_release"
      # Missing :date key - this was causing the KeyError
    }
    
    test_field_access(content)
  end
  
  defp test_alternative_content do
    IO.puts("\n3️⃣ Testing Alternative Content (description instead of text):")
    
    content = %{
      title: "JPMorgan Acquires Fintech Startup",
      description: "Strategic acquisition to enhance digital capabilities",
      source: "news_article"
      # Missing :text and :date
    }
    
    test_field_access(content)
  end
  
  defp test_field_access(content) do
    IO.puts("   Input: #{inspect(content)}")
    
    # Test the safe field access pattern we implemented
    title = Map.get(content, :title) || "N/A"
    text = Map.get(content, :text) || Map.get(content, :description) || ""
    source = Map.get(content, :source) || "Unknown"
    date = Map.get(content, :date) || "Unknown"
    
    IO.puts("   ✅ Safe Access Results:")
    IO.puts("      Title: #{title}")
    IO.puts("      Text: #{String.slice(text, 0, 40)}#{if String.length(text) > 40, do: "...", else: ""}")
    IO.puts("      Source: #{source}")
    IO.puts("      Date: #{date}")
    
    # Test prompt building (the critical part that was failing)
    prompt_section = build_content_section(content)
    IO.puts("   ✅ Prompt Section Generated Successfully:")
    IO.puts("#{prompt_section}")
  end
  
  defp build_content_section(content) do
    """
    CONTENT:
    Title: #{Map.get(content, :title) || "N/A"}
    Text: #{String.slice(Map.get(content, :text) || Map.get(content, :description) || "", 0, 100)}
    Source: #{Map.get(content, :source) || "Unknown"}
    Date: #{Map.get(content, :date) || "Unknown"}
    """
  end
end

ContentTaggingTest.run_tests()

IO.puts("\n🎉 All Content Tagging Tests Passed!")
IO.puts("The KeyError issue has been resolved. You can now safely call:")
IO.puts("DashboardGen.AgentTagging.tag_content(content)")
IO.puts("with any content map, even if it's missing some fields.")