" Settings:

" g:pyenv_venv_name
" g:pyenv_docker_image_name
" g:pyenv_log
" g:pyenv_packages
" g:pyenv_python_version

let s:packages = [
\   'flake8',
\   'pylint',
\   'python-language-server',
\   'pyls-black',
\   'pyls-isort',
\]

let s:docker_tmp_container_name = 'pyenv_tmp'

let s:version_cmd = '%s -c "import platform; print(platform.python_version())"'
let s:std_lib_path_cmd = '%s -c "import os; print(os.path.dirname(os.__file__))"'
let s:site_packages_path_cmd = '%s -c "import site; print(''\n''.join(site.getsitepackages()))"'

let s:pyenv_install_cmd = 'pyenv install -s %s'
let s:pyenv_prefix_cmd = 'pyenv prefix %s'
let s:pyenv_version_cmd = 'pyenv version-name'

let s:pyenv_venv_create_cmd = 'pyenv virtualenv %s %s'
let s:pyenv_venv_delete_cmd = 'pyenv virtualenv-delete -f %s'

let s:docker_cp_cmd = 'docker cp %s:%s/. %s'
let s:docker_run_cmd = 'docker run --rm %s %s'
let s:docker_create_tmp_container_cmd = 'docker create --name=%s %s'
let s:docker_rm_tmp_container_cmd = 'docker rm -f %s'

let s:pip_upgrade_cmd = '%s -m pip install --upgrade pip'
let s:pip_install_cmd = '%s -m pip install --no-cache-dir %s'

let s:generate_tags_cmd = 'cd %s && ctags -R --languages=python --kinds-python=cf'

func! s:get_option(key, ...)
    if has_key(g:, a:key)
        return get(g:, a:key)
    else
        return get(a:, 1, v:null)
    endif
endfunc

func! s:trim(str)
    return substitute(a:str, '\n\+$', '', '')
endfunc

func! s:systemlist(command)
    echom a:command
    return call('systemlist', [a:command])
endfunc

func! s:system(command)
    echom a:command
    return s:trim(call('system', [a:command]))
endfunc

func! s:_get_site_packages_path(cmd)
    let l:result = filter(
    \   s:systemlist(a:cmd),
    \   {path -> match(path, '\vsite-packages$')}
    \)
    return len(l:result) == 1 ? l:result[0] : v:null
endfunc

func! s:get_site_packages_path(venv_path)
    return s:_get_site_packages_path(
    \   printf(
    \       s:site_packages_path_cmd,
    \       s:get_venv_python_path(a:venv_path)
    \   )
    \)
endfunc

func! s:get_std_lib_path(venv_path)
    return s:system(
    \   printf(
    \       s:std_lib_path_cmd,
    \       s:get_venv_python_path(a:venv_path)
    \   )
    \)
endfunc

func! s:get_docker_site_packages_path()
    return s:_get_site_packages_path(
    \   printf(
    \       s:docker_run_cmd,
    \       g:pyenv_docker_image_name,
    \       printf(
    \           s:site_packages_path_cmd,
    \           'python',
    \       )
    \   )
    \)
endfunc

func! s:get_docker_python_version()
    return s:system(
    \   printf(
    \       s:docker_run_cmd,
    \       g:pyenv_docker_image_name,
    \       printf(
    \           s:version_cmd,
    \           'python',
    \       )
    \   )
    \)
endfunc

func! s:pyenv_venv_create(python_version, name)
    return s:system(
    \   printf(
    \       s:pyenv_venv_create_cmd,
    \       a:python_version, a:name
    \   )
    \)
endfunc

func! s:pyenv_venv_delete(name)
    return s:system(
    \   printf(
    \       s:pyenv_venv_delete_cmd,
    \       a:name
    \   )
    \)
endfunc

func! s:pip_upgrade(venv_path)
    return s:system(
    \   printf(
    \       s:pip_upgrade_cmd,
    \       s:get_venv_python_path(a:venv_path),
    \   )
    \)
endfunc

func! s:pip_install(venv_path, packages)
    return s:system(
    \   printf(
    \       s:pip_install_cmd,
    \       s:get_venv_python_path(a:venv_path),
    \       join(a:packages, ' ')
    \   )
    \)
endfunc

func! s:pyenv_install(version)
    return s:system(printf(s:pyenv_install_cmd, a:version))
endfunc

func! s:get_pyenv_version()
    return s:system(s:pyenv_version_cmd)
endfunc

func! s:get_venv_path(name)
    return s:system(printf(s:pyenv_prefix_cmd, a:name))
endfunc

func! s:get_venv_bin_path(venv_path)
    return a:venv_path . '/bin'
endfunc

func! s:get_venv_python_path(venv_path)
    return s:get_venv_bin_path(a:venv_path) . '/python'
endfunc

func! s:docker_create_tmp_container()
    return s:system(
    \   printf(
    \       s:docker_create_tmp_container_cmd,
    \       s:docker_tmp_container_name,
    \       g:pyenv_docker_image_name
    \   )
    \)
endfunc

func! s:docker_rm_tmp_container()
    return s:system(
    \   printf(
    \       s:docker_rm_tmp_container_cmd,
    \       s:docker_tmp_container_name
    \   )
    \)
endfunc

func! s:docker_cp(source_path, dest_path)
    return s:system(
    \   printf(
    \       s:docker_cp_cmd,
    \       s:docker_tmp_container_name,
    \       a:source_path,
    \       a:dest_path
    \   )
    \)
endfunc

func! s:copy_docker_site_packages(site_packages_path)
    let l:docker_site_packages_path = s:get_docker_site_packages_path()
    call s:docker_create_tmp_container()
    call s:docker_cp(l:docker_site_packages_path, a:site_packages_path)
    call s:docker_rm_tmp_container()
endfunc

func! s:set_path(path)
    if stridx($PATH, a:path) < 0
        let $PATH = a:path . ':' . $PATH
    endif
endfunc

func! s:set_neomake_pylint(site_packages_path)
    if !exists('g:neomake')
        return
    endif

    let g:neomake_python_pylint_exe = 'env'
    let g:neomake_python_pylint_args = [
    \   printf('PYTHONPATH=%s', a:site_packages_path),
    \   'pylint'
    \] + neomake#makers#ft#python#pylint().args
endfunc

func! s:set_virtual_env(path)
    if stridx($VIRTUAL_ENV, a:path) < 0 && isdirectory(a:path)
        let $VIRTUAL_ENV=a:path
    endif
endfunc

func! s:generate_tags(paths)
    for l:path in a:paths
        call s:system(printf(s:generate_tags_cmd, l:path))
    endfor
endfunc

func! s:set_tags(paths)
    let l:paths = map(deepcopy(a:paths), {index, value -> value . '/tags'})
    let l:paths = filter(l:paths, {index, value -> stridx(&tags, value) < 0})
    let &tags = join([&tags] + l:paths, ",")
endfunc

func! s:get_python_version()
    let l:result = s:get_option('pyenv_python_version')
    if empty(l:result) && !empty(s:get_option('pyenv_docker_image_name'))
        let l:result = s:get_docker_python_version()
    endif
    if empty(l:result)
        let l:result = s:get_pyenv_version()
    endif
    return l:result
endfunc

func! s:pyenv_install_python(version)
    if a:version != 'system'
        call s:pyenv_install(a:version)
    endif
endfunc

func s:create_service_venv()
    let l:venv_name = s:get_option('pyenv_venv_name')
    if empty(l:venv_name)
        return
    endif
    let l:venv_name = l:venv_name . '_service'

    let l:python_version = s:get_python_version()
    call s:pyenv_install_python(l:python_version)

    call s:pyenv_venv_delete(l:venv_name)
    call s:pyenv_venv_create(l:python_version, l:venv_name)

    let l:venv_path = s:get_venv_path(l:venv_name)

    call s:pip_upgrade(l:venv_path)
    call s:pip_install(l:venv_path, s:packages + s:get_option('pyenv_packages', []))
endfunc

func s:create_project_venv()
    let l:venv_name = s:get_option('pyenv_venv_name')
    if empty(l:venv_name)
        return
    endif

    let l:python_version = s:get_python_version()
    call s:pyenv_install_python(l:python_version)

    call s:pyenv_venv_delete(l:venv_name)
    call s:pyenv_venv_create(l:python_version, l:venv_name)

    let l:venv_path = s:get_venv_path(l:venv_name)
    let l:site_packages_path = s:get_site_packages_path(l:venv_path)
    let l:std_lib_path = s:get_std_lib_path(l:venv_path)
    call s:generate_tags([l:std_lib_path, l:site_packages_path])

    if !empty(s:get_option('pyenv_docker_image_name'))
        call s:copy_docker_site_packages(l:site_packages_path)
    endif
endfunc

func! s:init_project_env()
    let l:venv_name = s:get_option('pyenv_venv_name')
    if empty(l:venv_name)
        return
    endif

    let l:venv_path = s:get_venv_path(l:venv_name)
    if !isdirectory(l:venv_path)
        return
    endif

    let l:site_packages_path = s:get_site_packages_path(l:venv_path)
    call s:set_neomake_pylint(l:site_packages_path)

    let l:std_lib_path = s:get_std_lib_path(l:venv_path)
    call s:set_tags([l:std_lib_path, l:site_packages_path])
endfunc

func! s:init_service_env()
    let l:venv_name = s:get_option('pyenv_venv_name')
    if empty(l:venv_name)
        return
    endif
    let l:venv_name = l:venv_name . '_service'
    let l:venv_path = s:get_venv_path(l:venv_name)
    if !isdirectory(l:venv_path)
        return
    endif
    call s:set_path(s:get_venv_bin_path(l:venv_path))
endfunc

command! PyenvCreateServiceVenv call s:create_service_venv()
command! PyenvCreateProjectVenv call s:create_project_venv()

call s:init_service_env()
autocmd VimEnter * call s:init_project_env()
