-- Relative links (e.g. ../VERSIONS.md) don't exist inside the EPUB, so point
-- them at the file in the GitHub repository instead. Set the base URL with
-- -M repo_url=https://github.com/OWNER/REPO/blob/REF
local repo_url

function Meta(meta)
  repo_url = meta.repo_url and pandoc.utils.stringify(meta.repo_url)
end

function Link(link)
  local target = link.target
  if repo_url == nil or target:match("^%a[%w+.-]*:") or target:match("^#") then
    return nil
  end
  -- Chapters live in book/, so resolve the path relative to it.
  local path = ("book/" .. target):gsub("[^/]+/%.%./", "")
  link.target = repo_url .. "/" .. path
  return link
end

return { { Meta = Meta }, { Link = Link } }
