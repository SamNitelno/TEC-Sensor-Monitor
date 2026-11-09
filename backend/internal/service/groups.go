package service

import (
	"context"
	"fmt"

	"github.com/jackc/pgx/v5"

	"tek-sensor-monitor/backend/internal/apperr"
	"tek-sensor-monitor/backend/internal/jsonx"
	"tek-sensor-monitor/backend/internal/models"
	"tek-sensor-monitor/backend/internal/store"
)

// WorkshopHasSites is returned (409) instead of the former 500 when a
// workshop that still contains sites is deleted.
const WorkshopHasSites = "Нельзя удалить цех: в нём есть площадки. Сначала удалите или перенесите их."

func toWorkshop(w *models.Workshop) WorkshopResponse {
	return WorkshopResponse{ID: w.ID, Name: w.Name, Color: w.Color, NotificationsEnabled: w.NotificationsEnabled,
		CreatedAt: jsonx.NewTime(w.CreatedAt)}
}

func toSite(st *models.Site) (SiteResponse, error) {
	if st.WorkshopID == nil {
		return SiteResponse{}, apperr.New(500, fmt.Sprintf("Site %d has no workshop assigned", st.ID))
	}
	return SiteResponse{ID: st.ID, Name: st.Name, WorkshopID: *st.WorkshopID, Color: st.Color,
		NotificationsEnabled: st.NotificationsEnabled, CreatedAt: jsonx.NewTime(st.CreatedAt)}, nil
}

// ---- workshops -------------------------------------------------------------

func (s *Service) ListWorkshops(ctx context.Context) ([]WorkshopResponse, error) {
	ws, err := store.ListWorkshops(ctx, s.Pool)
	if err != nil {
		return nil, err
	}
	out := make([]WorkshopResponse, 0, len(ws))
	for i := range ws {
		out = append(out, toWorkshop(&ws[i]))
	}
	return out, nil
}

func (s *Service) CreateWorkshop(ctx context.Context, name string, color *string) (*WorkshopResponse, error) {
	w, err := store.CreateWorkshop(ctx, s.Pool, name, color)
	if err != nil {
		return nil, err
	}
	r := toWorkshop(w)
	return &r, nil
}

type WorkshopUpdateRequest struct {
	Name                 *string
	Color                *string
	ClearColor           bool
	NotificationsEnabled *bool
}

func (s *Service) UpdateWorkshop(ctx context.Context, id int64, req WorkshopUpdateRequest) (*WorkshopResponse, error) {
	var w *models.Workshop
	err := s.tx(ctx, func(tx pgx.Tx) error {
		var err error
		w, err = store.GetWorkshop(ctx, tx, id)
		if err != nil {
			return err
		}
		if w == nil {
			return apperr.NotFound("Workshop not found")
		}
		if req.Name != nil {
			w.Name = *req.Name
		}
		if req.ClearColor {
			w.Color = nil
		} else if req.Color != nil {
			w.Color = req.Color
		}
		if req.NotificationsEnabled != nil {
			w.NotificationsEnabled = *req.NotificationsEnabled
		}
		if err := store.SaveWorkshop(ctx, tx, w); err != nil {
			return err
		}
		if req.NotificationsEnabled != nil {
			if err := store.SetWorkshopSensorsNotifications(ctx, tx, id, *req.NotificationsEnabled); err != nil {
				return err
			}
			return store.SetSitesNotifications(ctx, tx, &id, *req.NotificationsEnabled)
		}
		return nil
	})
	if err != nil {
		return nil, err
	}
	r := toWorkshop(w)
	return &r, nil
}

func (s *Service) DeleteWorkshop(ctx context.Context, id int64) error {
	return s.tx(ctx, func(tx pgx.Tx) error {
		w, err := store.GetWorkshop(ctx, tx, id)
		if err != nil {
			return err
		}
		if w == nil {
			return apperr.NotFound("Workshop not found")
		}
		n, err := store.CountWorkshopSites(ctx, tx, id)
		if err != nil {
			return err
		}
		if n > 0 {
			return apperr.Conflict(WorkshopHasSites)
		}
		return store.DeleteWorkshop(ctx, tx, id)
	})
}

func (s *Service) SetAllWorkshopNotifications(ctx context.Context, enabled bool) (*BulkNotificationsResponse, error) {
	var count int
	err := s.tx(ctx, func(tx pgx.Tx) error {
		ws, err := store.ListWorkshops(ctx, tx)
		if err != nil {
			return err
		}
		count = len(ws)
		if err := store.SetAllWorkshopsNotifications(ctx, tx, enabled); err != nil {
			return err
		}
		if err := store.SetSitesNotifications(ctx, tx, nil, enabled); err != nil {
			return err
		}
		_, err = store.SetAllSensorsNotifications(ctx, tx, enabled)
		return err
	})
	if err != nil {
		return nil, err
	}
	return &BulkNotificationsResponse{Updated: int64(count)}, nil
}

// ---- sites -----------------------------------------------------------------

func (s *Service) ListSites(ctx context.Context, workshopID *int64) ([]SiteResponse, error) {
	sites, err := store.ListSites(ctx, s.Pool, workshopID)
	if err != nil {
		return nil, err
	}
	out := make([]SiteResponse, 0, len(sites))
	for i := range sites {
		r, err := toSite(&sites[i])
		if err != nil {
			return nil, err
		}
		out = append(out, r)
	}
	return out, nil
}

func (s *Service) CreateSite(ctx context.Context, name string, workshopID int64, color *string) (*SiteResponse, error) {
	w, err := store.GetWorkshop(ctx, s.Pool, workshopID)
	if err != nil {
		return nil, err
	}
	if w == nil {
		return nil, apperr.NotFound("Workshop not found")
	}
	st, err := store.CreateSite(ctx, s.Pool, name, workshopID, color)
	if err != nil {
		return nil, err
	}
	r, err := toSite(st)
	return &r, err
}

type SiteUpdateRequest struct {
	Name                 *string
	WorkshopID           *int64
	Color                *string
	ClearColor           bool
	NotificationsEnabled *bool
}

func (s *Service) UpdateSite(ctx context.Context, id int64, req SiteUpdateRequest) (*SiteResponse, error) {
	var st *models.Site
	err := s.tx(ctx, func(tx pgx.Tx) error {
		var err error
		st, err = store.GetSite(ctx, tx, id)
		if err != nil {
			return err
		}
		if st == nil {
			return apperr.NotFound("Site not found")
		}
		if req.WorkshopID != nil {
			w, err := store.GetWorkshop(ctx, tx, *req.WorkshopID)
			if err != nil {
				return err
			}
			if w == nil {
				return apperr.NotFound("Workshop not found")
			}
			st.WorkshopID = req.WorkshopID
		}
		if req.Name != nil {
			st.Name = *req.Name
		}
		if req.ClearColor {
			st.Color = nil
		} else if req.Color != nil {
			st.Color = req.Color
		}
		if req.NotificationsEnabled != nil {
			st.NotificationsEnabled = *req.NotificationsEnabled
		}
		if err := store.SaveSite(ctx, tx, st); err != nil {
			return err
		}
		if req.NotificationsEnabled != nil {
			return store.SetSiteSensorsNotifications(ctx, tx, id, *req.NotificationsEnabled)
		}
		return nil
	})
	if err != nil {
		return nil, err
	}
	r, err := toSite(st)
	return &r, err
}

func (s *Service) DeleteSite(ctx context.Context, id int64) error {
	return s.tx(ctx, func(tx pgx.Tx) error {
		st, err := store.GetSite(ctx, tx, id)
		if err != nil {
			return err
		}
		if st == nil {
			return apperr.NotFound("Site not found")
		}
		return store.DeleteSite(ctx, tx, id)
	})
}

func (s *Service) SetAllSiteNotifications(ctx context.Context, enabled bool) (*BulkNotificationsResponse, error) {
	var count int
	err := s.tx(ctx, func(tx pgx.Tx) error {
		sites, err := store.ListSites(ctx, tx, nil)
		if err != nil {
			return err
		}
		count = len(sites)
		if err := store.SetSitesNotifications(ctx, tx, nil, enabled); err != nil {
			return err
		}
		for _, st := range sites {
			if err := store.SetSiteSensorsNotifications(ctx, tx, st.ID, enabled); err != nil {
				return err
			}
		}
		return nil
	})
	if err != nil {
		return nil, err
	}
	return &BulkNotificationsResponse{Updated: int64(count)}, nil
}
