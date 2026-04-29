import { useLayerStore } from '@/stores/canwa'
import { ProjectsView } from './views/ProjectsView'
import { EditorView } from './views/EditorView'

export default function ImageEditorApp() {
  const viewMode = useLayerStore(s => s.viewMode)

  if (viewMode === 'editor') {
    return <EditorView />
  }

  return <ProjectsView />
}
