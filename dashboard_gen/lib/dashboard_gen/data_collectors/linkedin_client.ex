defmodule DashboardGen.DataCollectors.LinkedInClient do
  @moduledoc """
  Collects post data from LinkedIn for sentiment analysis.

  Requires a valid LinkedIn API access token in the environment:

      LINKEDIN_ACCESS_TOKEN="your_linkedin_access_token_here"

  To enable reading organization posts, likes, and comments, set up a LinkedIn Developer App
  with the appropriate permissions (e.g. r_organization_social, r_organization_traction).
  """

  require Logger

  @doc """
  Placeholder for LinkedIn data collection. Currently returns zero posts.

  ## Parameters

    - companies: a list of company names or identifiers

  ## Returns

    - `{:ok, count}` with the number of items processed
    - `{:error, reason}` on failure
  """
  @spec collect_mentions([String.t()]) :: {:ok, non_neg_integer()} | {:error, String.t()}
  def collect_mentions(companies) when is_list(companies) do
    Logger.warning("LinkedInClient.collect_mentions/1 is not yet implemented. Returning 0 posts.")
    {:ok, 0}
  end

  def collect_mentions(_), do: {:error, "Invalid companies list"}
end
