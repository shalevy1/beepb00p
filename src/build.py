#!/usr/bin/env python3
from pathlib import Path
import sys
from shutil import rmtree
from subprocess import check_call
from typing import List

# TODO sanity check that there are noexport entries or some private tags (e.g. people mentioned)
# ./check

# cargo install mdbook && mdbook init


def ccall(*args, **kwargs):
    print(args, file=sys.stderr)
    return check_call(*args, **kwargs)

# TODO https://rust-lang.github.io/mdBook/format/config.html

# https://github.com/rust-lang/mdBook/blob/master/book-example/book.toml
# TODO editable?
# TODO huh, that actually would be nice. I could fix stuff in-place and then apply to org-mode
# TODO search settings?
# TODO wonder if I can integrate it with blog's header?
# TODO export txt files as md as well?

from compile_org import emacs


root_dir = Path(__file__).absolute().parent.parent
input_dir  = root_dir / 'input'
public_dir = root_dir / 'public'
md_dir     = root_dir / 'markdown'
html_dir   = root_dir / 'html'

input_dir   = input_dir .resolve() # ugh. otherwise relative links might end up weird during org-publish-cache-ctime-of-src
public_dir  = public_dir.resolve()
md_dir      = md_dir    .resolve()
html_dir    = html_dir  .resolve()


mdbook  = 'mdbook'
builtin = 'builtin' # builtin emacs export


mdbook_output  = root_dir / 'output'

def clean_dir(path: Path) -> None:
    assert path.is_dir(), path
    for x in path.iterdir():
        if x.is_file():
            x.unlink()
        else: # dir
            rmtree(x)


def clean() -> None:
    # todo ugh, need symlink watching tool here again...
    cachedir = Path('~/.org-timestamps').expanduser()
    # TODO not sure about removing all of it...
    for c in cachedir.glob('*.cache'):
        c.unlink()

    clean_dir(md_dir)
    clean_dir(html_dir)

    # TODO what about empty dirs?
    for f in public_dir.rglob('*.org'):
        f.unlink()


def main() -> None:
    import argparse
    p = argparse.ArgumentParser()
    p.add_argument('--add', action='store_true')
    args = p.parse_args()
    target = builtin

    clean()

    eargs = [
        '--eval', f'''(progn
            (setq exobrain/input-dir  "{input_dir}" )
            (setq exobrain/public-dir "{public_dir}")
            (setq exobrain/md-dir     "{md_dir}"    )
            (setq exobrain/html-dir   "{html_dir}"  )
        )''',
        '--directory', root_dir / 'src/advice-patch',
        '--load', root_dir / 'src/publish.el',
        '-f', 'toggle-debug-on-error', # dumps stacktrace on error
        # adjust this variable to change the pipeline
        '--eval', f'''
(let ((org-publish-project-alist `(
        ,exobrain/project-preprocess-org
        {",exobrain/project-org2md" if target == mdbook else ",exobrain/project-org2html"}
       )))
  (org-publish-all))
'''.strip(),
    ]
    with emacs(*eargs) as ep:
        pass
    assert ep.returncode == 0

    # TODO need to clean public dir??
    # TODO call check_org after preprocess-org instead??
    from check import check_org
    check_org(public_dir)

    # TODO think about commit/push/deploy logic?
    assert (public_dir / '.git').is_dir(), public_dir
    ccall(['git', 'status'], cwd=public_dir)

    if args.add:
        ccall(['git', 'add', '-A', '--intent-to-add'], cwd=public_dir)
        ccall(['git', 'add', '-p'], cwd=public_dir)
        # TODO suggest to commit/push?

    if target == mdbook:
        postprocess_mdbook()
    elif target == builtin:
        postprocess_builtin()
    else:
        raise AssertionError(target)

def postprocess_builtin():
    sitemap = html_dir / 'sitemap.html'
    assert sitemap.exists()
    import bs4 # type: ignore
    soup = bs4.BeautifulSoup(sitemap.read_text(), 'lxml')
    node = soup.find(id='content')
    node.select_one('.title').decompose()
    node.name = 'nav' # div by deafult
    node['id'] = 'sidebar'
    toc = node.prettify()
    for html in html_dir.rglob('*.html'):
        if html == sitemap:
            continue
        depth = len(html.relative_to(html_dir).parts) - 1
        tocr = toc.replace(
            'href="',
            'href="' + ('' if depth == 0 else '../' * depth),
        )

        text = html.read_text()
        text = text.replace(
            '\n<body>\n',
            '\n<body>\n' + tocr,
        )
        html.write_text(text)

def postprocess_mdbook():
    # mdbook doesn't like summary format so we fix it
    # TODO reorder index?
    # todo what's that for??
    ccall(r"awk -i inplace !/\[README\]/  markdown/SUMMARY.md".split())
    # TODO clean first?
    ccall(['mdbook', 'build'])

    # meh. but it works :shrug:
    loc = '<h1 class="menu-title">exobrain</h1>'
    link = '<a style="font-size: 2rem; line-height: var(--menu-bar-height);" href="https://beepb00p.xyz">back to blog</a>'
    patched: List[Path] = []
    for html in mdbook_output.rglob('*.html'):
        body = html.read_text()
        if loc not in body:
            continue
        body = body.replace(loc, link + loc, 1)
        html.write_text(body)
        patched.append(html)
        # ugh. fine, keep it non-atomic for now...
        # https://github.com/untitaker/python-atomicwrites/issues/42
        # from atomicwrites import atomic_write
        # # with atomic_write(str(html), mode='w', overwrite=True) as fo:
        #     fo.write(body)

    assert len(patched) > 0 # just in case
    # patch in link to the blog..
    style="font-size: 2rem;/*! text-align: center; *//*! display: inline-block; *//*! font-weight: 200; *//*! flex: 1; *//*! text-align: left; */line-height: var(--menu-bar-height);"


if __name__ == '__main__':
    # TODO allow skipping?
    check_call(['mypy', '--check-untyped', __file__])
    main()
